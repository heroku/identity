$stdout.sync = $stderr.sync = true

require "bundler/setup"
Bundler.require

require "./lib/identity"

Slim::Engine.set_default_options pretty: !Config.production?

run Identity::Main
