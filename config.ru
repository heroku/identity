$stdout.sync = $stderr.sync = true

require "bundler/setup"
Bundler.require

require "./lib/identity"

Airbrake.configure do |config|
  config.api_key = Identity::Config.airbrake_api_key
end if Identity::Config.airbrake_api_key
Excon.defaults[:ssl_verify_peer] = Identity::Config.ssl_verify_peer?
Slim::Engine.set_default_options pretty: !Identity::Config.production?

run Identity::Main
