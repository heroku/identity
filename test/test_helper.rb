# seed the environment
ENV["COOKIE_ENCRYPTION_KEY"] = "another-super-secret-ultra-secure-key"
ENV["HEROKU_ROOT_DOMAIN_COOKIE_ENCRYPTION_KEY"] = "my-key" * 50
ENV["DASHBOARD_URL"]         = "https://dashboard.heroku.com"
ENV["SSO_BASE_URL"]          = "https://sso.heroku.com"
ENV["HEROKU_API_URL"]        = "https://api.heroku.com"
ENV["HEROKU_OAUTH_ID"]       = "46307a2b-0397-4739-b2b7-2f67d1cff597"
ENV["HEROKU_OAUTH_SECRET"]   = "b6c6aa58-3219-4642-add9-6d8008b268f6"
# set before using Bundler
ENV["RACK_ENV"]              = "test"
ENV["SIGNUP_URL"]            = "https://signup.heroku.com"

require "bundler/setup"
Bundler.require(:default, :test)

require "capybara"
require "minitest/autorun"
require "minitest/spec"
require "rack/test"
require "webmock/minitest"

require_relative "../lib/identity"
require_relative "service_stubs"

WebMock.disable_net_connect!

# suppress logging
module Slides
  def self.log(action, data={}, &block)
    yield(block) if block
  end

  def self.log_array(action, data, &block)
    yield(block) if block
  end
end

class MiniTest::Spec
  include RR::Adapters::TestUnit
end
