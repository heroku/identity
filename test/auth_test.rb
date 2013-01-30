require_relative "test_helper"

describe Identity::Auth do
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Session::Cookie
      use Rack::Flash
      run Identity::Auth
    end
  end

  before do
    stub_heroku_api
  end

  describe "POST /oauth/authorize" do
    it "responds to GET as well" do
      get "/oauth/authorize"
      assert_equal 302, last_response.status
    end
  end

  describe "GET /sessions" do
    it "shows a login page" do
      get "/sessions/new"
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

    it "redirects to login on a failed login" do
      stub_heroku_api do
        #post("/oauth/authorizations") { 401 }
        # webmock doesn't handle Excon's :expects, so raise error directly
        # until it does
        post("/oauth/authorizations") { raise(Excon::Errors::Forbidden, "Forbidden") }
      end
      post "/sessions", email: "kerry@heroku.com", password: "abcdefgh"
      assert_equal 302, last_response.status
      assert_match %r{/sessions/new$}, last_response.headers["Location"]
    end
  end

  describe "DELETE /sessions" do
    it "clears session and redirects to login" do
      delete "/sessions"
      assert_equal 302, last_response.status
      assert_match %r{/sessions/new$}, last_response.headers["Location"]
    end
  end

  it "stores and replays /oauth/authorize attempt when not logged in" do
    post "/oauth/authorize", client_id: "abcdef"
    assert_equal 302, last_response.status
    assert_match %r{/sessions/new$}, last_response.headers["Location"]

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

  describe "untrusted client" do
    before do
      stub_heroku_api do
        get("/oauth/clients/:id") {
          MultiJson.encode({
            trusted: false
          })
        }
      end
    end

    it "confirms with the user before authorizing" do
      post "/sessions", email: "kerry@heroku.com", password: "abcdefgh"
      post "/oauth/authorize", client_id: "untrusted"
      assert_equal 200, last_response.status
    end

    it "creates an authorization after a user confirms" do
      post "/sessions", email: "kerry@heroku.com", password: "abcdefgh"
      post "/oauth/authorize", client_id: "untrusted", authorize: "Authorize"
      assert_equal 302, last_response.status
    end
  end
end
