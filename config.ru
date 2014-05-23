#config.ru

require File.expand_path '../app.rb', __FILE__

run Rack::URLMap.new({
  "/" => Protected
})
