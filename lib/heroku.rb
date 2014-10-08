require './lib/emails'
require './config/env'

class HerokuAPI
  include HTTParty
  base_uri 'https://api.heroku.com'
  format :json
  headers 'Accept' => 'application/vnd.heroku+json; version=3'
  headers 'Authorization' => HEROKU_API_TOKEN
end
  

class Heroku

  def initialize(app_name)
    @app_name = app_name
    @redis_key = redis_key(app_name)
  end

  def heroku_rollback
  
    releases = HerokuAPI.get "/apps/#{@app_name}/releases"
  
    previous_release = releases[-2]
    payload = {:release => previous_release["id"]}
  
    new_release = HerokuAPI.post("/apps/#{@app_name}/releases", :body => payload)
    
    {
      :previus_release => previous_release,
      :new_release => new_release,
    }
  end

  def reachable?
    response = HerokuAPI.get "/apps/#{@app_name}/releases"
    response.code == 200
  end
    

  def notification_or_rollback(email, payload)
    email = $redis.hget(@redis_key, 'email')
    $redis.del(@redis_key)

    unless ROLLBACK_ENABLED
      send_email_rollback_request(@app_name, email, payload)
      response.status = 201
      return {:status => '201', :reason => 'Rollback disabled, only this email is sent'}.to_json
    end

    begin
        result = self.heroku_rollback @app_name if ROLLBACK_ENABLED
    rescue
      send_email_rollback_failed(@app_name, email) if EMAIL_ENABLED
      response.status = 500
      return {:status => '500', :reason => 'Rollback rejected by Heroku'}
    else
      if result[:new_release].code == 201

        if EMAIL_ENABLED
          send_email_rollback(@app_name, email, payload)
        end
          
        response.status = 201
        {
          :status => 'ok',
          :new_release => result[:new_release]
        }.to_json
      else
        send_email_rollback_failed(@app_name, email, result) if EMAIL_ENABLED
        response.status = result[:new_release].code
        result[:new_release]
      end
    end
  end
end


