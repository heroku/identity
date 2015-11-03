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

    it "redirects to dashboard on a successful confirmation" do
      any_instance_of(Identity::Cookie) do |cookie|
        stub(cookie).access_token { "abc123" }
      end
      get "/account/email/confirm/c45685917ef644198a0fececa10d479a"
      assert_equal 302, last_response.status
      assert_match Identity::Config.dashboard_url,
        last_response.headers["Location"]
    end

    it "shows a helpful page for a token that wasn't found" do
      any_instance_of(Identity::Cookie) do |cookie|
        stub(cookie).access_token { "abc123" }
      end
      stub_heroku_api do
        patch "/users/~" do
          halt(404, "Not found")
        end
      end
      get "/account/email/confirm/c45685917ef644198a0fececa10d479a"
      assert_equal 200, last_response.status
      assert_match(/couldn't find that e-mail/, last_response.body)
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

    it "redirects when the api responded with an error" do
      stub_heroku_api do
        post "/password-resets" do
          [422, MultiJson.encode({ message: "Fail" })]
        end
      end
      post "/account/password/reset", email: "kerry@heroku.com"
      assert_equal 302, last_response.status
      assert last_response.headers["Location"] =~ %r{/account/password/reset$}
    end
  end

  describe "GET /account/password/reset/:token" do
    it "renders a password reset form" do
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

    [ 403, 422 ].each do |error_code|
      it "redirects back to reset page when there's a #{error_code} error" do
        stub_heroku_api do
          post "/users/:token/actions/finalize-password-reset" do
            [ error_code, MultiJson.encode({ message: "a #{error_code} error" }) ]
          end
        end
        post "/account/password/reset/c45685917ef644198a0fececa10d479a",
          password: "1234567890ab", password_confirmation: "1234567890ab"
        assert_equal 302, last_response.status
        assert_match %r{/account/password/reset/c45685917ef644198a0fececa10d479a$}, last_response.headers["Location"]
        follow_redirect!
        assert_match /a #{error_code} error/, last_response.body
      end
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
      assert_equal "#{Identity::Config.signup_url}/foo?from=id",
        last_response.headers["Location"]
    end

    it "sets the redirect-url so the user is taken back when authorizing a client" do
      url = "https://id.heroku.com/oauth/authorize/1234"
      rack_env = {
        # set a cookie
        "rack.session" => { "post_signup_url" => url }
      }
      get "/signup/foo", {}, rack_env
      expected_params = {
        "from" => "id",
        "redirect-url" => url
      }
      encoded_params = URI.encode_www_form(expected_params)
      assert_equal 302, last_response.status
      assert_equal "#{Identity::Config.signup_url}/foo?#{encoded_params}",
        last_response.headers["Location"]
    end
  end

  describe "GET /account/two-factor/recovery" do
    it "renders a recovery form" do
      get "/account/two-factor/recovery"
      assert_equal 200, last_response.status
      refute_match /code via SMS/, last_response.body
    end

    it "renders a recovery form with SMS if present" do
      get "/account/two-factor/recovery", {}, 'rack.session' => { :email => 'two@heroku.com', :password => '' }
      assert_equal 200, last_response.status
      assert_match /code via SMS/, last_response.body
    end
  end

  describe "GET /account/two-factor/recovery/sms" do
    it "renders a sms recovery form" do
      get "/account/two-factor/recovery/sms", {}, 'rack.session' => { :email => 'two@heroku.com', :password => '' }
      assert_equal 200, last_response.status
      assert_match /\+1 \*\*\* 1234/, last_response.body
      assert_match /Resend SMS/, last_response.body
    end
  end

  describe "POST /account/two-factor/recovery/sms" do
    it "redirects back to two-factor if number missing" do
      stub_heroku_api do
        post("/users/~/sms-number/actions/recover") {
          [422, MultiJson.encode({ message: "Number missing." })]
        }
      end

      post "/account/two-factor/recovery/sms"
      assert_equal 302, last_response.status
      assert_match %r{/login/two-factor$}, last_response.headers["Location"]
    end
  end
end
