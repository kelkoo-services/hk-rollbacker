require 'httparty'
require 'redis'
require 'time'
require './emails'
require './lib/utils'
require 'active_support/time'
require 'sidekiq'


NOT_VALID_CODES = [
  '500',
  '522',
]


def check_app_status(app)
    response = HTTParty.get(TEST_URIS[app])
    if NOT_VALID_CODES.include? response.code
      return false
    else
      return true
    end
end



class MonitoringJob
  include Sidekiq::Worker
  def perform(app, email)
    logger.info 'Running checker'
    rkey = redis_key(app)

    now = Time.now.getutc
    $redis.hset(rkey, "last_update", now)
    
    if check_app_status(app)
      $redis.hincrby(rkey, "ok", 1)
      logger.info 'Increasing OK'
    else
      $redis.hincrby(rkey, "errors", 1)
      logger.info 'Incresing Errors'
    end

    r_ok = $redis.hget(rkey, "ok") 
    r_errors = $redis.hget(rkey, "errors")
    retries = r_ok.to_i + r_errors.to_i
    logger.info "Retries: #{retries}"

    if r_errors.to_i >= LIMIT_ERRORS
      logger.warn "Hey, there is something wrong with the app"
      # TODO Notification and rollback if enabled
      return
    end

    if retries.to_i < MAX_RETRIES
      logger.info "Enqueueing a new job"
      MonitoringJob.perform_in(5.seconds, app, email)
    else
      logger.info "No more tests"
      $redis.del(rkey)
    end
    

  end
end
