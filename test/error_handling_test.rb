require_relative "test_helper"

describe Identity::ErrorHandling do
  include Rack::Test::Methods

  def app
    Sinatra.new do
      register Identity::ErrorHandling

      set :views, "#{Identity::Config.root}/views"

      get "/401" do
        raise Excon::Errors::Unauthorized.new("go away")
      end

      get "/404" do
        raise Excon::Errors::NotFound.new("not found")
      end

      get "/429" do
        raise Excon::Errors::TooManyRequests.new("too many")
      end

      get "/503" do
        raise Excon::Errors::Timeout.new("timeout")
      end
    end
  end

  describe "401" do
    it "renders the 401 error page" do
      get "/401"
      assert_equal 401, last_response.status
      assert_match /Your credentials are invalid/, last_response.body
    end
  end

  describe "404" do
    it "renders the 404 error page" do
      get "/404"
      assert_equal 404, last_response.status
      assert_match /but we couldn't find that page/, last_response.body
    end
  end

  describe "429" do
    it "renders the 429 error page" do
      get "/429"
      assert_equal 429, last_response.status
      assert_match /Too Many Requests/, last_response.body
    end
  end

  describe "unavailable errors" do
    it "renders the 503 error page" do
      get "/503"
      assert_equal 503, last_response.status
      assert_match /Unavailable/, last_response.body
    end
  end
end
