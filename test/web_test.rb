require_relative "test_helper"

describe Identity::Web do
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Session::Cookie
      use Rack::Flash
      run Identity::Web
    end
  end

  before do
    stub_heroku_api
  end

  describe "GET /account/new" do
    it "shows a new account page" do
      get "/account/new"
      assert_equal 200, last_response.status
    end
  end

  describe "POST /account" do
    it "creates an account and renders a notice" do
      stub_heroku_api
      post "/account", email: "kerry@heroku.com"
      assert_equal 200, last_response.status
      assert_match %{Confirmation email sent}, last_response.body
    end
  end

  describe "GET /account/password/reset" do
    it "shows a reset password form" do
      get "/account/password/reset"
      assert_equal 200, last_response.status
    end
  end

  describe "POST /account/password/reset" do
    it "requests a password reset" do
      stub_heroku_api
      post "/account/password/reset", email: "kerry@heroku.com"
      assert_equal 200, last_response.status
    end

    it "renders when the api responded with an error" do
      stub_heroku_api do
        post("/auth/reset_password") { 422 }
      end
      post "/account/password/reset", email: "kerry@heroku.com"
      assert_equal 200, last_response.status
    end
  end

  describe "GET /account/password/reset/:hash" do
    it "renders a password reset form" do
      stub_heroku_api
      get "/account/password/reset/c45685917ef644198a0fececa10d479a"
      assert_equal 200, last_response.status
    end
  end

  describe "POST /account/password/reset/:hash" do
    it "changes a password and redirects to login" do
      stub_heroku_api
      post "/account/password/reset/c45685917ef644198a0fececa10d479a",
        password: "1234567890ab", password_confirmation: "1234567890ab"
      assert_equal 302, last_response.status
      assert_match %r{/sessions/new$}, last_response.headers["Location"]
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
  end

  describe "DELETE /sessions" do
    it "clears session and redirects to login" do
      delete "/sessions"
      assert_equal 302, last_response.status
      assert_match %r{/sessions/new$}, last_response.headers["Location"]
    end
  end

  it "stores and replays /oauth/authorize attempt when not logged in" do
    stub_heroku_api do
      post("/oauth/authorize") { 401 }
    end
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
end
