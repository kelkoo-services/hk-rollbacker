
def check_url_status(url)
    response = HTTParty.get(url)
    if NOT_VALID_CODES.include? response.code
      return false
    else
      return true
    end
end

def check_app_status(app)
    url = $redis.hget(redis_key('apps'), app)
    logger.debug "Checking app #{url}"
    check_url_status(url)
end

def newrelic_payload_validation(payload, app)
  return false if payload.nil?
  return false unless payload.values_at("application_name", "severity") == [app, "downtime"]
  return false unless (
    payload.has_key?("short_description") &&
    /^(New alert|Escalated severity).*$/.match(payload["short_description"])
  )
  return true
end


def redis_key(name)
  name + "_hkrollbacker"
end
