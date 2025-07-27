# config.ru
require './app'
require_relative './config/initialize'

# Tell Rack to run the controllers
run Rack::URLMap.new({
  "/" => PaymentsController.new
})
