#config.ru

require File.expand_path '../app.rb', __FILE__

$stdout.sync = true

run Rack::URLMap.new({
  "/" => Protected
})
