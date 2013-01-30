$stdout.sync = $stderr.sync = true

require "bundler/setup"
Bundler.require

require "./lib/identity"

Excon.defaults[:ssl_verify_peer] = Identity::Config.ssl_verify_peer?
Slim::Engine.set_default_options pretty: !Identity::Config.production?

run Identity::Main
