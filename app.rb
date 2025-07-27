# app.rb
require 'sinatra'
require 'active_record'
require 'pg'
require 'json'
require 'dotenv/load' if development?
require 'sidekiq'
require 'erb' # Required for processing ERB in YAML files

# --- Configuration ---
# Tell ActiveRecord where to find the database configuration
set :database_file, "config/database.yml"
# Set the environment for Sinatra and ActiveRecord
set :environment, :development

# --- Load Application Files ---
# Load all .rb files from the subdirectories
Dir["./entities/*.rb"].each { |file| require file }
Dir["./services/*.rb"].each { |file| require file }
Dir["./jobs/*.rb"].each { |file| require file }
Dir["./controllers/*.rb"].each { |file| require file }

# --- Sidekiq Configuration ---
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }

  # --- FIX for ActiveRecord Connection and Pooling Errors ---
  # Get the database configuration for the current environment
  # The `aliases: true` flag is required for modern Ruby versions to parse YAML anchors.
  # We must first process the file with ERB to evaluate the embedded Ruby code.
  db_config_yaml = ERB.new(File.read('config/database.yml')).result
  db_config = YAML.safe_load(db_config_yaml, aliases: true)[ENV['RACK_ENV'] || 'development']


  # Set the ActiveRecord connection pool size to be at least the Sidekiq concurrency.
  # Sidekiq's default concurrency is 10, while ActiveRecord's default pool size is 5,
  # which causes connection errors. This ensures the pool is always large enough.
  db_config['pool'] = config.concurrency + 2 # A little buffer is good practice

  # Establish the database connection for the Sidekiq server process
  ActiveRecord::Base.establish_connection(db_config)
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
