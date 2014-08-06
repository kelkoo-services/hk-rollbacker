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

  def heroku_rollback (app_name)
  
    releases = HerokuAPI.get "/apps/#{app_name}/releases"
  
    previous_release = releases[-2]
    payload = {:release => previous_release["id"]}
  
    new_release = HerokuAPI.post("/apps/#{app_name}/releases", :body => payload)
    
    {
      :previus_release => previous_release,
      :new_release => new_release,
    }
  end

  def notification_or_rollback(app, email)
    email = $redis.hget(redis_key(app_name), 'email')
    $redis.del(redis_key(app_name))

    unless ROLLBACK_ENABLED
      send_email_rollback_request(app_name, email, payload)
      response.status = 201
      return {:status => '201', :reason => 'Rollback disabled, only this email is sent'}.to_json
    end

    begin
        result = self.heroku_rollback app_name if ROLLBACK_ENABLED
    rescue
      send_email_rollback_failed(app_name, email, payload) if EMAIL_ENABLED
      response.status = 500
      return {:status => '500', :reason => 'Rollback rejected by Heroku'}
    else
      if result[:new_release].code == 201
        response.status = 201

        if EMAIL_ENABLED
          send_email_rollback(app_name, email, payload)
        end
          
        {
          :status => 'ok',
          :new_release => result[:new_release]
        }.to_json
      else
        send_email_rollback_failed(app_name, email, result) if EMAIL_ENABLED
        response.status = result[:new_release].code
        result[:new_release]
      end
    end
  end
end


