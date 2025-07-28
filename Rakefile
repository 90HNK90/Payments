require 'active_record'
require 'standalone_migrations'
require_relative 'app'

db_config_yaml = ERB.new(File.read('config/database.yml')).result
db_config = YAML.safe_load(db_config_yaml, aliases: true)[ENV['RACK_ENV'] || 'development']
ActiveRecord::Base.establish_connection(db_config)

StandaloneMigrations::Tasks.load_tasks
