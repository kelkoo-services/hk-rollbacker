
HTTP_USER = ENV['HTTP_USER'] 
raise 'HTTP_USER bad format (user:password hashed with sha256) ' unless (HTTP_USER != nil && HTTP_USER.include?(':'))

API_KEY = ENV['API_KEY']
NEWRELIC_API_ID= ENV['NEWRELIC_API_ID']
HEROKU_API_TOKEN = ENV['HEROKU_API_TOKEN']
REDIS_URI = ENV['REDIS_URI'] || ENV['REDISTOGO_URL'] || ENV['OPENREDIS_URL'] || 'redis://localhost:6379/'
DEPLOY_TTL = (ENV['DEPLOY_TTL'] || 300)
EMAIL_ENABLED = ENV['EMAIL_ENABLED'] == 'true'
ROLLBACK_ENABLED = ENV['ROLLBACK_ENABLED'] == 'true'

MAX_RETRIES = (ENV['MAX_RETRIES'] || 5).to_i
RETRIES_BY_STEP = (ENV['RETRIES_BY_STEP'] || 3).to_i
LIMIT_ERRORS = (ENV['LIMIT_ERRORS'] || 2).to_i
APPS_WAKEUP = (ENV['APPS_WAKEUP'] || 10).to_i

if ENV['EMAIL_ENABLED'] == 'true'
  MAILER = {
    :host => ENV['EMAIL_HOST'] || ENV['MAILGUN_SMTP_SERVER'] || '127.0.0.1',
    :port => (ENV['EMAIL_PORT'] || ENV['MAILGUN_SMTP_PORT'] || 25).to_i,
    :user => ENV['EMAIL_USER'] || ENV['MAILGUN_SMTP_LOGIN'] || false,
    :password => ENV['EMAIL_PASSWORD'] || ENV['MAILGUN_SMTP_PASSWORD'],
    :from => ENV['EMAIL_FROM'] || 'rollbacker@anyexample.com',
    :subject_prefix => ENV['EMAIL_SUBJECT_PREFIX'] || '[ROLLBACKER]',
    :alwayscc => ENV['EMAIL_ALWAYS_CC'] || false
  }
  MAILER[:domain] = ENV['EMAIL_DOMAIN'] || MAILER[:from].split('@')[-1]
end
