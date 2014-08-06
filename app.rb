require 'sinatra/base'
require 'haml'
require 'newrelic_rpm'
require 'httparty'
require 'json'
require 'digest'
require 'redis'
require 'time'
require './app/workers/monitoring'
require './lib/utils'
require './config/env'
require 'active_support/time'


# Expected environment
#  APPS = "app1;app2;app3"  # heroku app names
#  HTTP_USER = "user:SHA256passwordhashed"
#  API_KEY = "SHA256passwordhashed"
#  HEROKU_API_TOKEN = "echo {email}{API TOKEN} | base64"  # Token api from heroku with rollback available
#  REDIS_URI = "REDIS://:password@host:port"  # (localhost by default)
#  DEPLOY_TTL = 300  # seconds



$redis = Redis.new(:url => REDIS_URI)


def init_tests(app, email)
    now = Time.now.getutc
    data = {
      :app => app,
      :email => email,
      :timestamp => now.getutc.to_i,
      :monitoring => true,
      :date => now,
      :ok => 0,
      :errors => 0,
      :last_request => nil,
    }

    $redis.mapped_hmset(redis_key(app), data)

    MonitoringJob.perform_in(APPS_WAKEUP.to_i.seconds, app, email)
end


class Protected < Sinatra::Base
  def auth_basic?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    stored_user, stored_password = HTTP_USER.split(':')
    unless @auth.provided? && @auth.basic? && @auth.credentials 
      return false
    end

    password_hash = Digest::SHA256.new() << @auth.credentials[1] 
    (@auth.credentials[0] == stored_user && password_hash = stored_password)
  end

  def auth_apikey?
    return false unless params[:key]
    password_hash = Digest::SHA256.new() << params[:key]
    password_hash == API_KEY
  end

  def authorized?
    auth_basic? || auth_apikey? 
  end


  before do
    $redis.set("started", Time.now.getutc)
    if not authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, "Not authorized\n"
    end
  end


  post '/:app/newrelease/' do
    app_name = params[:app]
    unless APPS.include?(app_name)
      response.status = 404
      return {:status => '404', :reason => 'Not found'}.to_json
    end

    payload = JSON.parse request.body.read

    unless payload.has_key?('email')
      response.status = 400
      return {:status => '400', :reason => 'email is required'}.to_json
    end

    now = Time.now.getutc
    data = {
      :app => app_name,
      :email => payload['email'],
      :timestamp => now.getutc.to_i,
      :date => now,
    }

    $redis.multi do
      $redis.mapped_hmset(redis_key(app_name), data)
      $redis.expire(redis_key(app_name), DEPLOY_TTL)
    end

    response.status = 201
    return {:status => '201', :status => "OK"}.to_json
  end

  get '/' do
    @apps_status = APPS.map {|name| {
      :name => name,
      :date => $redis.hget(redis_key(name), 'date'),
      :monitoring => $redis.hget(redis_key(name), 'monitoring'),
    }}
    haml :index
  end


  post '/heroku-post' do
    app_name = params.get('app')

    unless APPS.include?(app_name)
      response.status = 404
      return {:status => '404', :reason => 'Not found'}.to_json
    end

    email = params.get('user')
    url = params.get('url')
    logger.log(url)

    if email == $redis.hget(redis_key(app_name), 'email') &&
        $redis.hget(redis_key(app_name), 'monitoring')
      
      response.status = '412'
      return {:status => '412', :reason => "Already monitoring one deployment"}.to_json
    end

    init_tests(app_name, email)

    response.status = 201
    {:status => 'ok'}.to_json
  end

  get '/manualtest' do
    app_name = "patata"
    email = "someone@example.com"

    if $redis.hexists(redis_key(app_name), 'monitoring')
      response.status = 412
      return {:status => '412', :reason => "Already monitoring one deployment for this app"}.to_json
    end

    init_tests(app_name, email)

    haml :ok
  end
end
