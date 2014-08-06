
Sidekiq.configure_server do |config|
  config.redis = { :url =>  ENV['REDIS_URI'] || ENV['REDISTOGO_URL'] || ENV['OPENREDIS_URL'] || 'redis://localhost:6379/' }
end
