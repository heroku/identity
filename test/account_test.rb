require_relative "test_helper"

describe Identity::Account do
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Session::Cookie, secret: "my-secret"
      use Rack::Flash
      run Identity::Account
    end
  end

  before do
    stub_heroku_api
    rack_mock_session.clear_cookies
  end

  describe "GET /account" do
    it "responds with 401 without a session" do
      get "/account"
      assert_equal 401, last_response.status
    end

    it "responds with a 401 with an invalid session" do
      stub_heroku_api do
        get "/account" do
          halt 401
        end
      end
      authorize "", "secret"
      get "/account"
      assert_equal 401, last_response.status
    end

    it "proxies to the API" do
      stub_heroku_api do
        get "/account" do
          "{}"
        end
      end
      authorize "", "secret"
      get "/account"
      assert_equal 200, last_response.status
      assert_equal "{}", last_response.body
    end
  end

  describe "GET /account/accept/:id/:token" do
    it "redirects to the same path in the signup app" do
      stub(Identity::Config).redirect_all_signups { true }
      get "/account/accept/123/456abc"
      assert_equal 302, last_response.status
      assert_equal "#{Identity::Config.signup_url}/account/accept/123/456abc?from=id", last_response.headers["Location"]
    end
  end

  describe "POST /account/accept/ok" do
    it "redirects to the signup app" do
      stub(Identity::Config).redirect_all_signups { true }
      post "/account/accept/ok"
      assert_equal 302, last_response.status
      assert_equal "#{Identity::Config.signup_url}/account/accept/ok?from=id", last_response.headers["Location"]
    end
  end

  describe "GET /account/accept/ok" do
    it "redirects to the signup app" do
      get "/account/accept/ok"
      assert_equal 302, last_response.status
      assert_equal "#{Identity::Config.signup_url}/account/accept/ok?from=id", last_response.headers["Location"]
    end
  end

  describe "GET /account/email/confirm/:token" do
    it "requires login" do
      get "/account/email/confirm/c45685917ef644198a0fececa10d479a"
      assert_equal 302, last_response.status
      assert_match %r{/login$}, last_response.headers["Location"]
    end

# proving VERY difficult to test in isolation, need a cookie
=begin
    it "redirects to dashboard on a successful confirmation" do
      stub_heroku_api
      get "/account/email/confirm/c45685917ef644198a0fececa10d479a"
      assert_equal 302, last_response.status
      assert_match Identity::Config.dashboard_url,
        last_response.headers["Location"]
    end

    it "shows a helpful page for a token that wasn't found" do
      stub_heroku_api do
        post("/confirm_change_email/:token") {
          raise Excon::Errors::NotFound, "Not found"
        }
      end
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      get "/account/email/confirm/c45685917ef644198a0fececa10d479a"
      assert_equal 200, last_response.status
      assert_match /couldn't find that e-mail/, last_response.body
    end
=end
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

    it "redirects when the api responded with an error" do
      stub_heroku_api do
        post("/auth/reset_password") {
          [422, MultiJson.encode({ message: "Password too short." })]
        }
      end
      post "/account/password/reset", email: "kerry@heroku.com"
      assert_equal 302, last_response.status
      assert last_response.headers["Location"] =~ %r{/account/password/reset$}
    end
  end

  describe "GET /account/password/reset/:token" do
    it "renders a password reset form" do
      stub_heroku_api
      get "/account/password/reset/c45685917ef644198a0fececa10d479a"
      assert_equal 200, last_response.status
    end
  end

  describe "POST /account/password/reset/:token" do
    it "changes a password and redirects to login" do
      stub_heroku_api
      post "/account/password/reset/c45685917ef644198a0fececa10d479a",
        password: "1234567890ab", password_confirmation: "1234567890ab"
      assert_equal 302, last_response.status
      assert_match %r{/login$}, last_response.headers["Location"]
    end
  end

  describe "GET /signup" do
    it "redirects to the root of the signup app" do
      get "/signup"
      assert_equal 302, last_response.status
      assert_equal "#{Identity::Config.signup_url}?from=id", last_response.headers["Location"]
    end
  end

  describe "GET /signup/:slug" do
    it "redirects to the same slug in the signup app" do
      get "/signup/foo"
      assert_equal 302, last_response.status
      assert_equal "#{Identity::Config.signup_url}/foo?from=id", last_response.headers["Location"]
    end
  end
end
