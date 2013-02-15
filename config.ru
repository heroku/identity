$stdout.sync = $stderr.sync = true

require "bundler/setup"
Bundler.require

require "./lib/identity"

# initialization/configuration
Airbrake.configure do |config|
  config.api_key = Identity::Config.airbrake_api_key
end if Identity::Config.airbrake_api_key
Excon.defaults[:ssl_verify_peer] = Identity::Config.ssl_verify_peer?
Rack::Instruments.configure do |config|
  config.id_generator = -> { SecureRandom.uuid }
end
Slim::Engine.set_default_options pretty: !Identity::Config.production?

run Identity::Main
