worker_processes 1 || ENV['UNICORNS']
timeout 30
preload_app true

sidekiq_workers = 1 || ENV['SIDEKIQ_WORKERS']

before_fork do |server, worker|
  @sidekiq_pid ||= spawn("bundle exec sidekiq -r ./app.rb -c #{sidekiq_workers}") if ENV['SIDEKIQ_INTERNAL'] == 'true'
end
