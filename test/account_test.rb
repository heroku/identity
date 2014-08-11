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

  describe "GET /account/accept/:id/:token" do
    it "shows a form to finish signup" do
      get "/account/accept/123/456abc"
      assert_equal 200, last_response.status
    end

    it "displays an unckecked checkbox for subcribing to newsletter when the request comes from a country which requires it" do
      stub_heroku_api
      any_instance_of(Geocoder::Result::Freegeoip) do |klass|
        stub(klass).country { 'Spain' }
      end
      get "/account/accept/123/456abc"
      assert_equal 200, last_response.status
      assert last_response.body.include?('<input id="receive_newsletter" name="receive_newsletter" type="checkbox" value="true" />')
    end

    it "subscribes the user to the newsletter if the request doesn't come from a country which allows it" do
      stub_heroku_api
      any_instance_of(Geocoder::Result::Freegeoip) do |klass|
        stub(klass).country { 'Canada' }
      end
      get "/account/accept/123/456abc"
      assert_equal 200, last_response.status
      assert last_response.body.include?('<input checked="true" id="receive_newsletter" name="receive_newsletter" style="display:none" type="checkbox" value="true" />')
    end

    it "redirects to experimental signup when appropriate" do
      stub(Identity::Config).experimental_signup_slugs { ["experimental"] }
      stub(Identity::Config).experimental_signup_url {
        "http://experiment.heroku.com"
      }
      stub_heroku_api do
        get "/invitation2/show" do
          MultiJson.encode({
            signup_source_slug: "experimental?foo=bar",
          })
        end
      end
      get "/account/accept/123/456abc"
      assert_equal 302, last_response.status
      assert_equal "http://experiment.heroku.com/account/accept/123/456abc",
        last_response.headers["Location"]
    end
  end

  describe "POST /account/accept/ok" do
    it "completes then shows interstitial page" do
      post "/account/accept/ok"
      assert_equal 200, last_response.status
    end

    it "render interstitial and check meta content" do
      post "/account/accept/ok"
      assert_match <<-eos.strip, last_response.body
meta content="3;url=https://dashboard.heroku.com" http-equiv="refresh"
      eos
    end

    it "redirects to experimental signup when appropriate" do
      stub(Identity::Config).experimental_signup_slugs { ["experimental"] }
      stub(Identity::Config).experimental_signup_url {
        "https://experiment.heroku.com"
      }
      stub_heroku_api do
        post "/invitation2/save" do
          MultiJson.encode({
            email: "some@example.com",
            signup_source_slug: "experimental?foo=bar",
          })
        end
      end
      post "/account/accept/ok"
      assert_match <<-eos.strip, last_response.body
meta content="3;url=https://experiment.heroku.com/account/accept/ok" http-equiv="refresh"
      eos
    end
  end

  describe "GET /account/accept/ok" do
    it "redirects to dashboard.heroku.com/" do
      get "/account/accept/ok"
      assert_equal 302, last_response.status
      assert_equal "https://dashboard.heroku.com",
        last_response.headers["Location"]
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
    it "shows a new account page" do
      get "/signup"
      assert_equal 200, last_response.status
    end
  end

  describe "GET /signup/:slug" do
    it "redirects to the signup app preserving query params if the slug is experimental" do
      stub(Identity::Config).experimental_signup_slugs { ["experimental"] }
      stub(Identity::Config).experimental_signup_url {
        "https://experiment.heroku.com"
      }
      get "/signup/experimental?foo=bar"
      assert_equal 302, last_response.status
      assert_equal "https://experiment.heroku.com/signup/experimental?foo=bar", last_response.headers["Location"]
    end

    it "shows a new account page" do
      get "/signup/facebook"
      assert_equal 200, last_response.status
    end
  end
end
