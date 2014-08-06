#config.ru

require File.expand_path '../app.rb', __FILE__
require 'sidekiq/web'

$stdout.sync = true

run Rack::URLMap.new({
  '/sidekiq' => Sidekiq::Web,
  "/" => Protected
})
