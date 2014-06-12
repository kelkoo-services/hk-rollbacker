require 'net/smtp'
require 'mailfactory'


if ENV['EMAIL_ENABLED'] == 'true'
  MAILER = {
    :host => ENV['EMAIL_HOST'] || ENV['MAILGUN_SMTP_SERVER'] || '127.0.0.1',
    :port => (ENV['EMAIL_PORT'] || ENV['MAILGUN_SMTP_PORT'] || 25).to_i,
    :user => ENV['EMAIL_USER'] || ENV['MAILGUN_SMTP_LOGIN'] || false,
    :password => ENV['EMAIL_PASSWORD'] || ENV['MAILGUN_SMTP_PASSWORD'],
    :from => ENV['EMAIL_FROM'] || 'rollbacker@anyexample.com',
    :subject_prefix => ENV['EMAIL_SUBJECT_PREFIX'] || '[ROLLBACKER]',
    :alwayscc => ENV['EMAIL_ALLWAYS_CC'] || false
  }
  MAILER[:domain] = ENV['EMAIL_DOMAIN'] || MAILER[:from].split('@')[-1]
else
  EMAIL_ENABLED=false
end


def send_email(email, subject, body)
  mail = MailFactory.new()
  mail.to = email
  if MAILER[:alwayscc]
    mail.cc = MAILER[:alwayscc]
  end
  mail.from = MAILER[:from]
  mail.subject = subject
  mail.text = body

  mail_connection = [
    MAILER[:host], 
    MAILER[:port],
    MAILER[:domain],
  ]

  emails = [
    MAILER[:alwayscc],
    email
  ]

  if MAILER[:user]
    mail_connection << MAILER[:user] << MAILER[:password] << :login
  end
    Net::SMTP.start(*mail_connection) do |smtp|
    smtp.send_message(mail.to_s, MAILER[:from], *emails)
  end
end


def send_email_rollback(app_name, email, payload)
  body = <<EOM
There is a rollback in process because the rollbacker app has received 
a web hook from New Relic for #{app_name}
    #{payload.to_s}

EOM
  subject = "#{MAILER[:subject_prefix]} [#{app_name}] ROLLBACK IN PROGRESS!!"
  send_email(email, subject, body)
end


def send_email_rollback_failed(app_name, email, payload)
  body = <<EOM
We have received a request to do a rollback in the app #{app_name} but the
rollback request process has failed in Heroku system.

    #{payload.to_s}

EOM
  subject = "#{MAILER[:subject_prefix]} [#{app_name}] ROLLBACK REQUESTED FAILED!!"
  send_email(email, subject, body)
end


def send_email_rollback_request(app_name, email, payload)
  body = <<EOM
We have received a request to do a rollback in the app #{app_name} but the
rollback request process is disabled.

    #{payload.to_s}

EOM
  subject = "#{MAILER[:subject_prefix]} [#{app_name}] ROLLBACK REQUESTED, but rollback is disabled!!"
  send_email(email, subject, body)
end
