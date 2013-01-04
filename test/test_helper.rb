# set before using Bundler
ENV["RACK_ENV"] = "test"

require "bundler/setup"
Bundler.require(:default, :test)

require "minitest/autorun"
require "minitest/spec"
require "rack/test"
require "webmock/minitest"

require_relative "../lib/identity"
require_relative "service_stubs"

class MiniTest::Spec
  include RR::Adapters::TestUnit
end
