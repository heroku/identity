# set before using Bundler
ENV["RACK_ENV"] = "test"

require "bundler/setup"
Bundler.require(:default, :test)

require "minitest/autorun"
require "minitest/spec"
require "rack/test"

require_relative "../lib/identity"

class MiniTest::Spec
  include RR::Adapters::TestUnit
end
