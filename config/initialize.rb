# config/initialize.rb
require 'bundler/setup'
Bundler.require

require 'active_record'
require 'yaml'
require 'erb' # FIX: Require ERB to process the database.yml file

# --- 1. Set Environment ---
# Determines the environment (development, production, etc.). Defaults to 'development'.
APP_ENV = ENV.fetch('RACK_ENV', 'development')

# --- 2. Establish Database Connection ---
# Loads the database configuration from a YAML file.
db_config_path = File.expand_path('database.yml', __dir__)

# FIX: Process the YAML file through ERB first to handle environment variables.
db_config_file = ERB.new(File.read(db_config_path)).result
db_config = YAML.load(db_config_file, aliases: true)

# Establishes the connection for the current environment.
ActiveRecord::Base.establish_connection(db_config[APP_ENV])
puts "[Initializer] ActiveRecord connection established for '#{APP_ENV}' environment."

# --- 3. Load Application Models ---
# Loads all .rb files from the 'models' directory.
# This makes classes like Company and Payment available to the application.
Dir["./models/**/*.rb"].each { |file| require file }
puts "[Initializer] Application models loaded."

# --- 4. Load Application Services and Jobs ---
# Ensure all other application code is loaded.
# Adjust the paths if your directory structure is different.
Dir["./services/**/*.rb"].each { |file| require file }
Dir["./jobs/**/*.rb"].each { |file| require file }
puts "[Initializer] Services and jobs loaded."
