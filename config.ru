$stdout.sync = $stderr.sync = true

require "bundler/setup"
Bundler.require

require "./lib/identity"

#
# initialization/configuration
#

Honeybadger.configure do |config|
  config.api_key = ENV['HONEYBADGER_API_KEY']
end if ENV['HONEYBADGER_API_KEY']
Excon.defaults[:ssl_verify_peer] = Identity::Config.ssl_verify_peer?
Slim::Engine.set_default_options pretty: !Identity::Config.production?

run Identity::Main
