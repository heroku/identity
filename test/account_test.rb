require_relative "test_helper"

describe Identity::Account do
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Session::Cookie
      use Rack::Flash
      run Identity::Account
    end
  end

  before do
    stub_heroku_api
  end

  describe "GET /account" do
    it "responds with 401 without a session" do
      get "/account"
      assert_equal 401, last_response.status
    end
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
end
