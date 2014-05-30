require 'sinatra/base'
require 'haml'
require 'newrelic_rpm'
require 'httparty'
require 'json'
require 'digest'
require 'redis'
require 'time'
require 'net/smtp'
require 'mailfactory'

# Expected environment
#  APPS = "app1;app2;app3"  # heroku app names
#  HTTP_USER = "user:SHA256passwordhashed"
#  HEROKU_API_TOKEN = "echo {email}{API TOKEN} | base64"  # Token api from heroku with rollback available
#  REDIS_URI = "REDIS://:password@host:port"  # (localhost by default)
#  DEPLOY_TTL = 300  # seconds


APPS = ENV['APPS'].split(';')
HTTP_USER = ENV['HTTP_USER']
HEROKU_API_TOKEN = ENV['HEROKU_API_TOKEN']
REDIS_URI = ENV['REDIS_URI'] || 'REDIS://localhost:6379/'
DEPLOY_TTL = ENV['DEPLOY_TTL'] || 300

if ENV['EMAIL_ENABLED'] == 'true'
  EMAIL_ENABLED=true
  MAILER = {
    :host => ENV['EMAIL_HOST'] || ENV['MAILGUN_SMTP_SERVER'] || '127.0.0.1',
    :port => ENV['EMAIL_PORT'] || ENV['MAILGUN_SMTP_SERVER'] || 25,
    :user => ENV['EMAIL_USER'] || ENV['MAILGUN_SMTP_LOGIN'] || false,
    :password => ENV['EMAIL_PASSWORD'] || ENV['MAILGUN_SMTP_PASSWORD'],
    :from => ENV['EMAIL_FROM'] || 'rollbacker@generic-rollback.com',
    :subject_prefix => ENV['EMAIL_SUBJECT_PREFIX'] || '[ROLLBACKER]',
    :alwayscc => ENV['EMAIL_ALLWAYS_CC'] || false
  }
else
  EMAIL_ENABLED=false
end


def send_email(app_name, email, payload)
  mail = MailFactory.new()
  mail.to = email
  if MAILER[:alwayscc]
    mail.cc = MAILER[:alwayscc]
  end
  mail.from = MAILER[:from]
  mail.subject = "#{MAILER[:subject_prefix]} [#{app_name}] ROLLBACK IN PROGRESS!!"
  mail.text <<EOF
There is a rollback in process because the rollbacker app has received 
a web hook from New Relic for #{app_name}

    #{payload.to_s}
EOF

  if MAILER[:user]
    mail_connection = [MAILER[:host], MAILER[:port], MAILER[:user], MAILER[:password]]
  else
    mail_connection = [MAILER[:host], MAILER[:port]]
  end

  Net::SMTP.send('start', *mail_connection) do |smtp|
    smtp.send_message(mail.to_s(), mail.from, mail.to)
  end
end


def newrelic_payload_validation(payload, app)
  return false if paload.nil?
  return false unless payload.at("account_name", "serverity") == [app, "downtime"]
  return false unless (
    payload.has_key?("message") &&
    /^(New alert|Escalated severity).*down$/.match(payload["message"])
  )
  return true
end


def redis_key(name)
  name + "_hkrollbacker"
end


class Heroku
  include HTTParty
  base_uri 'https://api.heroku.com'
  format :json
  headers 'Accept' => 'application/vnd.heroku+json; version=3'
  headers 'Authorization' => HEROKU_API_TOKEN
end
  

def heroku_rollback (app_name)

  releases = Heroku.get "/apps/#{app_name}/releases"

  previous_release = releases[-2]
  payload = {:release => previous_release["id"]}

  new_release = Heroku.post("/apps/#{app_name}/releases", :body => payload)
  
  {
    :previus_release => previous_release,
    :new_release => new_release,
  }
end


class Protected < Sinatra::Base
  use Rack::Auth::Basic, "Protected Area" do |username, password|
    stored_user, stored_password = HTTP_USER.split(':')
    password_hash = Digest::SHA256.new() << password
    username == stored_user && password_hash.hexdigest == stored_password
  end

  redis = Redis.new(:url => REDIS_URI)
  redis.set("started", Time.now.getutc)
  
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

    redis.multi do
      redis.mapped_hmset(redis_key(app_name), data)
      redis.expire(redis_key(app_name), DEPLOY_TTL)
    end

    response.status = 201
    {:status => 'ok'}.to_json
  end

  post '/:app/rollback/' do
    app_name = params[:app]
    payload = JSON.parse request.body.read

    unless APPS.include?(app_name)
      response.status = 404
      return {:status => '404', :reason => 'Not found'}.to_json
    end

    unless redis.exists(redis_key(app_name))
      response.status = 404
      return {:status => '404', :reason => 'Last deploy is expired'}.to_json
    end

    unless newrelic_payload_validation(payload)
      response.status = 400
      return {
        :status=> '400',
        :reason => 'Invalid json content, required severity and account_name and message ending with down'
      }.to_json
    end

    result = heroku_rollback app_name

    if result[:new_release].code == 201
      response.status = 201

      email = redis.hget(redis_key(app_name), 'email')

      redis.del(redis_key(app_name))

      if EMAIL_ENABLED
        send_email(app_name, email, payload)
      end
        
      {
        :status => 'ok',
        :new_release => result[:new_release]
      }.to_json
    else
      response.status = result[:new_release].code
      result[:new_release]
    end
  end

  get '/' do
    @apps_status = APPS.map {|name| {:name => name, :date => redis.hget(redis_key(name), 'date')}}
    haml :index
  end
end
