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
    rack_mock_session.clear_cookies
  end

  describe "POST /account" do
    it "creates an account and renders a notice" do
      post "/account", email: "kerry@heroku.com"
      assert_equal 200, last_response.status
      assert_match %{Confirmation email sent}, last_response.body
    end

    it "forwards a signup_source slug" do
      stub_heroku_api do
        post("/signup") {
          raise("need a slug") unless params[:slug]
          pass
        }
      end
      get "/signup", slug: "facebook"
      post "/account", email: "kerry@heroku.com"
    end

    it "appends tracking data to the signup_source slug" do
      rack_mock_session.set_cookie "utm_campaign=heroku-postgres"
      stub_heroku_api do
        post("/signup") {
          unless params[:slug].include?("utm_campaign=heroku-postgres")
            raise("expected utm_campaign in the slug")
          end
          pass
        }
      end
      get "/signup"
      post "/account", email: "kerry@heroku.com"
    end

    it "doesn't forward a signup_source slug if none given" do
      stub_heroku_api do
        post("/signup") {
          if params[:slug]
            raise("didn't expect a slug param, received: #{params[:slug]}")
          end
          pass
        }
      end
      get "/signup"
      post "/account", email: "kerry@heroku.com"
    end
  end

  describe "GET /account/accept/:id/:hash" do
    it "shows a form to finish signup" do
      get "/account/accept/123/456abc"
      assert_equal 200, last_response.status
    end
  end

  describe "POST /account/accept/:id/:hash" do
    it "completes then redirects" do
      post "/account/accept/123/456abc"
      assert_equal 302, last_response.status
      assert_match %r{https://dashboard.heroku.com$},
        last_response.headers["Location"]
    end
  end

  describe "GET /account/email/confirm/:hash" do
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

    it "shows a helpful page for a hash that wasn't found" do
      stub_heroku_api do
        post("/confirm_change_email/:hash") {
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

    it "renders when the api responded with an error" do
      stub_heroku_api do
        post("/auth/reset_password") {
          [422, MultiJson.encode({ message: "Password too short." })]
        }
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
      assert_match %r{/login$}, last_response.headers["Location"]
    end
  end

  describe "GET /signup" do
    it "shows a new account page" do
      get "/signup"
      assert_equal 200, last_response.status
    end
  end

  describe "GET /signup/:slug" do
    it "shows a new account page" do
      get "/signup/facebook"
      assert_equal 200, last_response.status
    end
  end
end
