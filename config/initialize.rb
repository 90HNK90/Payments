# config/initialize.rb
require 'bundler/setup'
Bundler.require

require 'active_record'
require 'yaml'
require 'erb'


APP_ENV = ENV.fetch('RACK_ENV', 'development')

db_config_path = File.expand_path('database.yml', __dir__)

db_config_file = ERB.new(File.read(db_config_path)).result
db_config = YAML.load(db_config_file, aliases: true)

ActiveRecord::Base.establish_connection(db_config[APP_ENV])

Dir["./models/**/*.rb"].each { |file| require file }
puts "[Initializer] Application models loaded."

Dir["./services/**/*.rb"].each { |file| require file }
Dir["./jobs/**/*.rb"].each { |file| require file }
