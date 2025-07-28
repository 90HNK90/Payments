require 'sinatra'
require 'active_record'
require 'pg'
require 'json'
require 'dotenv/load' if development?
require 'sidekiq'
require 'erb'

set :database_file, "config/database.yml"
set :environment, :development

Dir["./entities/*.rb"].each { |file| require file }
Dir["./services/*.rb"].each { |file| require file }
Dir["./jobs/*.rb"].each { |file| require file }
Dir["./controllers/*.rb"].each { |file| require file }

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  db_config_yaml = ERB.new(File.read('config/database.yml')).result
  db_config = YAML.safe_load(db_config_yaml, aliases: true)[ENV['RACK_ENV'] || 'development']
  db_config['pool'] = config.concurrency + 2 

  ActiveRecord::Base.establish_connection(db_config)
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
