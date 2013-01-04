require_relative "test_helper"

describe Identity::Web do
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Session::Cookie
      run Identity::Web
    end
  end

  before do
    stub_heroku_api
  end

  describe "GET /sessions" do
    it "shows a login page" do
      get "/sessions"
      assert_equal 200, last_response.status
    end
  end

  describe "POST /sessions" do
    it "logs a user in and redirects to dashboard" do
      post "/sessions", email: "kerry@heroku.com", password: "abcdefgh"
      assert_equal 302, last_response.status
      assert_equal Identity::Config.dashboard_url,
        last_response.headers["Location"]
    end
  end

  describe "DELETE /sessions" do
    it "clears session and redirects to login" do
      delete "/sessions"
      assert_equal 302, last_response.status
      assert_match %r{/sessions$}, last_response.headers["Location"]
    end
  end

  it "stores and replays /oauth/authorize attempt when not logged in" do
    stub_heroku_api do
      post("/oauth/authorize") { 401 }
    end
    post "/oauth/authorize", client_id: "abcdef"
    assert_equal 302, last_response.status
    assert_match %r{/sessions$}, last_response.headers["Location"]

    follow_redirect!
    post "/sessions", email: "kerry@heroku.com", password: "abcdefgh"
    assert_equal 302, last_response.status
    assert_equal "https://dashboard.heroku.com/oauth/callback/heroku" +
      "?code=454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
      last_response.headers["Location"]
  end

  it "is able to call /oauth/authorize after logging in" do
    post "/sessions", email: "kerry@heroku.com", password: "abcdefgh"
    assert_equal 302, last_response.status
    assert_equal "https://dashboard.heroku.com",
      last_response.headers["Location"]

    follow_redirect!
    post "/oauth/authorize", client_id: "abcdef"
    assert_equal 302, last_response.status
    assert_equal "https://dashboard.heroku.com/oauth/callback/heroku" +
      "?code=454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
      last_response.headers["Location"]
  end
end
