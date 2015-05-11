$stdout.sync = $stderr.sync = true

require "bundler/setup"
Bundler.require

require "./lib/identity"

#
# initialization/configuration
#

Rollbar.configure do |config|
  config.disable_monkey_patch = true
  config.access_token         = Identity::Config.rollbar_access_token
  config.enabled              = !Identity::Config.rollbar_access_token.nil?
  config.environment          = ENV["RACK_ENV"]
end

Excon.defaults[:ssl_verify_peer] = Identity::Config.ssl_verify_peer?
Slim::Engine.set_default_options pretty: !Identity::Config.production?

run Identity::Main
