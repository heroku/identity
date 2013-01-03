require_relative "test_helper"

describe Identity::Web do
  include Rack::Test::Methods

  def app
    Identity::Web
  end

  describe "GET /sessions" do
    it "shows a login page" do
      get "/sessions"
      assert_equal 200, last_response.status
    end
  end
end
