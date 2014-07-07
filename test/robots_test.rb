require_relative "test_helper"

describe Identity::Robots do
  include Rack::Test::Methods

  def app
    Identity::Robots
  end

  describe "GET /robots.txt" do
    it "responds with a robots file" do
      get "/robots.txt"
      assert_match /text\/plain/, last_response.headers["Content-Type"]
      assert_match /User-agent:/, last_response.body
      assert_match /Disallow:/, last_response.body
    end
  end
end
