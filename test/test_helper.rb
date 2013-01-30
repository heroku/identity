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

# suppress logging
module Slides
  def self.log(action, data={}, &block)
    yield(block) if block
  end
end

class MiniTest::Spec
  include RR::Adapters::TestUnit
end
