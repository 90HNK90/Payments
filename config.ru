# config.ru
require './app'
require_relative './config/initialize'

run Rack::URLMap.new({
  "/" => PaymentsController.new
})
