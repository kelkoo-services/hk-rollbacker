require 'sinatra/base'
require 'newrelic_rpm'
require 'rest_client'
require 'json'
require 'digest'
require 'redis'
require 'time'

# Expected environment
#  APPS = "app1;app2;app3"  # heroku app names
#  HTTP_USER = "user:SHA256passwordhashed"
#  HEROKU_API_TOKEN = "asdfasdf-asdf-asdf"  # Token api from heroku with rollback available
#  REDIS_URI = "REDIS://:password@host:port"  # (localhost by default)
#  DEPLOY_TTL = 300  # seconds



APPS = ENV['APPS'].split(';')
HTTP_USER = ENV['HTTP_USER']
HEROKU_API_TOKEN = ENV['HEROKU_API_TOKEN']
REDIS_URI = ENV['REDIS_URI'] || 'REDIS://localhost:6379/'
DEPLOY_TTL = ENV['DEPLOY_TTL'] || 300

class Protected < Sinatra::Base
  use Rack::Auth::Basic, "Protected Area" do |username, password|
    stored_user, stored_password = HTTP_USER.split(':')
    password_hash = Digest::SHA256.new() << password
    username == stored_user && password_hash.hexdigest == stored_password
  end

  redis = Redis.new(:url => REDIS_URI)
  redis.set("started", Time.now.getutc)
  
  post '/:app/deploying/' do
    app_name = params[:app]
    unless APPS.include?(app_name)
      response.status = 404
      return {:status => '404', :reason => 'Not found'}.to_json
    end

    if redis.exists(app_name)
      response.status = 409
      return {:status => '409', :reason => 'Already registered'}.to_json
    end

    payload = JSON.parse request.body.read

    now = Time.now.getutc
    data = {
      :app => app_name,
      :email => payload['email'],
      :timestamp => now.getutc.to_i,
      :date => now,
    }

    redis.multi do
      redis.mapped_hmset(app_name, data)
      redis.expire(app_name, DEPLOY_TTL)
    end

    response.status = 202
    {:status => 'ok'}.to_json
  end

  post '/:app/rollback/' do
    unless APPS.include?(params[:app])
      response.status = 404
      return {:status => '404', :reason => 'Not found'}.to_json
    end
    payload = JSON.parse(request.body.read)

    response.status = 202
    {:status => 'ok'}.to_json
  end

  get '/' do
    "This should be an application status list"
  end
end
