require 'httparty'
require 'redis'
require 'time'
require './lib/emails'
require './lib/utils'
require './lib/heroku'
require 'active_support/time'
require 'sidekiq'


NOT_VALID_CODES = [
  '500',
  '522',
]




class MonitoringJob
  include Sidekiq::Worker
  def perform(app, email)
    rkey = redis_key(app)
    logger.info "Running checker #{rkey}"

    now = Time.now.getutc
    $redis.hset(rkey, "last_update", now)
    
    $redis.hincrby(rkey, "retries", 1)
    retries = $redis.hget(rkey, "retries")

    0.upto(RETRIES_BY_STEP) do |i| 
      if check_app_status(app)
        $redis.hincrby(rkey, "ok", 1)
        logger.info "Reply from #{app} was fine"
      else
        $redis.hincrby(rkey, "errors", 1)
        logger.info "Reply from #{app} failed"
      end
      sleep 0.5
    end

    r_ok = $redis.hget(rkey, "ok") 
    r_errors = $redis.hget(rkey, "errors")

    logger.info "Total Retries: #{retries}"

    if r_errors.to_i >= LIMIT_ERRORS
      logger.warn "Hey, there is something wrong with the app"
      heroku = Heroku.new(app)
      heroku.notification_or_rollback(email, {
        :app => app,
        :email => email,
        :retires => retries,
        :requests_ok => r_ok,
        :requests_faield => r_errors,
      })
      site_error(app, email)
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
