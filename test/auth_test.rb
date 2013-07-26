require_relative "test_helper"

describe Identity::Auth do
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Session::Cookie, domain: "example.org"
      use Rack::Flash
      run Identity::Auth
    end
  end

  before do
    stub(Identity::Config).heroku_cookie_domain { ".example.org" }
    stub_heroku_api
    rack_mock_session.clear_cookies
  end

  describe "POST /oauth/authorize" do
    it "responds to GET as well" do
      get "/oauth/authorize"
      assert_equal 302, last_response.status
    end

    it "can be called by a user who is logged in" do
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      assert_equal 302, last_response.status
      assert_equal "https://dashboard.heroku.com",
        last_response.headers["Location"]

      follow_redirect!
      post "/oauth/authorize", client_id: "dashboard"
      assert_equal 302, last_response.status
      assert_equal "https://dashboard.heroku.com/oauth/callback/heroku" +
        "?code=454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
        last_response.headers["Location"]
    end

    it "stores and replays an authorization attempt when not logged in" do
      post "/oauth/authorize", client_id: "dashboard"
      assert_equal 302, last_response.status
      assert_match %r{/login$}, last_response.headers["Location"]

      follow_redirect!
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      assert_equal 302, last_response.status
      assert_equal "https://dashboard.heroku.com/oauth/callback/heroku" +
        "?code=454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
        last_response.headers["Location"]
    end

    describe "for an untrusted client" do
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
        post "/login", email: "kerry@heroku.com", password: "abcdefgh"
        post "/oauth/authorize", client_id: "untrusted"
        assert_equal 200, last_response.status
        assert_match /Allow Access/, last_response.body
      end

      it "creates an authorization after a user confirms" do
        post "/login", email: "kerry@heroku.com", password: "abcdefgh"

        # post once to get parameters stored to session
        post "/oauth/authorize", client_id: "untrusted"

        # then again to confirm
        post "/oauth/authorize", authorize: "Allow Access"
        assert_equal 302, last_response.status
        assert_equal "https://dashboard.heroku.com/oauth/callback/heroku" +
          "?code=454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
          last_response.headers["Location"]
      end

      it "does not create an authorization if a user confirms via GET" do
        post "/login", email: "kerry@heroku.com", password: "abcdefgh"

        # post once to get parameters stored to session
        post "/oauth/authorize", client_id: "untrusted"

        # then try again, but with the wrong request method (should be POST)
        get "/oauth/authorize", authorize: "Allow Access"
        assert_equal 200, last_response.status
        assert_match /Allow Access/, last_response.body
      end
    end
  end

  describe "POST /oauth/token" do
    it "renders access and refresh tokens" do
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      post "/oauth/authorize", client_id: "dashboard"
      post "/oauth/token"
      assert_equal 200, last_response.status
      tokens = MultiJson.decode(last_response.body)
      assert_equal "e51e8a64-29f1-4bbf-997e-391d84aa12a9", tokens["access_token"]
      assert_equal "faa180e4-5844-42f2-ad66-0c574a1dbed2", tokens["refresh_token"]
      assert_equal 7200, tokens["expires_in"]
    end

    it "accepts an authorization code" do
      i = 0
      stub_heroku_api do
        post("/oauth/tokens") {
          # only check parameters on the 2nd request, as ID does one OAuth
          # dance to procure its own token
          if (i += 1) > 1
            raise("missing_param=code")       unless params[:code]
            raise("missing_param=grant_type") unless params[:grant_type]
            raise("extra_param=refresh_token") if params[:refresh_token]
          end
          status(201)
          MultiJson.encode({
            authorization: {
              id: "authorization123@heroku.com",
            },
            access_token: {
              id:         "access-token123@heroku.com",
              token:      "e51e8a64-29f1-4bbf-997e-391d84aa12a9",
              expires_in: 7200,
            },
            refresh_token: {
              id:         "refresh-token123@heroku.com",
              token:      "faa180e4-5844-42f2-ad66-0c574a1dbed2",
              expires_in: 2592000,
            },
            session: {
              id:         "session123@heroku.com",
            },
            user: {
              session_nonce: "0a80ac35-b9d8-4fab-9261-883bea77ad3a",
            }
          })
        }
      end
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      post "/oauth/authorize", client_id: "dashboard"
      post "/oauth/token",
        grant_type: "authorization_code",
        code: "secret-auth-grant-code"
      assert_equal 200, last_response.status
    end

    it "accepts a refresh token" do
      i = 0
      stub_heroku_api do
        post("/oauth/tokens") {
          # only check parameters on the 2nd request, as ID does one OAuth
          # dance to procure its own token
          if (i += 1) > 1
            raise("missing_param=grant_type") unless params[:grant_type]
            raise("missing_param=refresh_token") unless params[:refresh_token]
            raise("extra_param=code") if params[:code]
          end
          status(201)
          MultiJson.encode({
            authorization: {
              id: "authorization123@heroku.com",
            },
            access_token: {
              id:         "access-token123@heroku.com",
              token:      "e51e8a64-29f1-4bbf-997e-391d84aa12a9",
              expires_in: 7200,
            },
            refresh_token: {
              id:         "refresh-token123@heroku.com",
              token:      "faa180e4-5844-42f2-ad66-0c574a1dbed2",
              expires_in: 2592000,
            },
            session: {
              id:         "session123@heroku.com",
            },
            user: {
              session_nonce: "0a80ac35-b9d8-4fab-9261-883bea77ad3a",
            }
          })
        }
      end
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      post "/oauth/authorize", client_id: "dashboard"
      post "/oauth/token",
        grant_type: "refresh_token",
        refresh_token: "secret-refresh-token"
      assert_equal 200, last_response.status
    end

    it "forwards a 401" do
      stub_heroku_api do
        post("/oauth/tokens") {
          raise Excon::Errors::Unauthorized.new("Unauthorized", nil,
            Excon::Response.new(body: "Unauthorized"))
        }
      end
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      post "/oauth/authorize", client_id: "dashboard"
      post "/oauth/token"
      assert_equal 401, last_response.status
    end
  end

  describe "GET /login" do
    it "shows a login page" do
      get "/login"
      assert_equal 200, last_response.status
    end
  end

  describe "POST /login" do
    it "logs a user in and redirects to dashboard" do
      post "/login", { email:  "kerry@heroku.com", password: "abcdefgh" },
        { "HTTP_X_FORWARDED_FOR" => "8.7.6.5" }
      assert_equal 302, last_response.status
      assert_equal Identity::Config.dashboard_url,
        last_response.headers["Location"]
    end

    it "redirects to login on a failed login" do
      stub_heroku_api do
        #post("/oauth/authorizations") { 401 }
        # webmock doesn't handle Excon's :expects, so raise error directly
        # until it does
        post("/oauth/authorizations") {
          raise(Excon::Errors::Unauthorized, "Unauthorized")
        }
      end
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      assert_equal 302, last_response.status
      assert_match %r{/login$}, last_response.headers["Location"]
    end

    it "sets a heroku-wide session nonce in the cookie" do
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"
      assert_equal "1",
        rack_mock_session.cookie_jar["heroku_session"]
      assert_equal "0a80ac35-b9d8-4fab-9261-883bea77ad3a",
        rack_mock_session.cookie_jar["heroku_session_nonce"]
    end

    describe "for accounts with two-factor enabled" do
      before do
        stub_heroku_api do
          post("/oauth/authorizations") {
            # two-factor challenge!
            pass if env["HTTP_HEROKU_TWO_FACTOR_CODE"] == "123456"

            # raise a 401 with a header telling the client to ask for the code
            response = OpenStruct.new(:headers => { "Heroku-Two-Factor-Required" => "true" })
            raise Excon::Errors::Forbidden.new("Forbidden", nil, response)
          }
        end
      end

      it "redirects to /login/two-factor to prompt for the code" do
        post "/login", email: "kerry@heroku.com", password: "abcdefgh"
        assert_equal 302, last_response.status
        assert_match %r{/login/two-factor$}, last_response.headers["Location"]
      end

      it "and then posts the authorization again, using the two-factor code" do
        post "/login", email: "kerry@heroku.com", password: "abcdefgh"
        follow_redirect!
        post "/login", :code => "123456"
        assert_equal 302, last_response.status
        assert_equal Identity::Config.dashboard_url,
          last_response.headers["Location"]
      end
    end
  end

  describe "DELETE /logout" do
    it "responds to GET as well" do
      get "/logout"
      assert_equal 302, last_response.status
    end

    it "clears session and redirects to login" do
      delete "/logout"
      assert_equal 302, last_response.status
      assert_match %r{/login$}, last_response.headers["Location"]
    end

    it "destroys heroku_* cookies" do
      # login to get the heroku cookies in our jar
      post "/login", email: "kerry@heroku.com", password: "abcdefgh"

      delete "/logout"
      assert_equal "", rack_mock_session.cookie_jar["heroku_session"]
      assert_equal "", rack_mock_session.cookie_jar["heroku_session_nonce"]
    end

    it "redirects to a given url if it's safe" do
      delete "/logout", url: "https://devcenter.heroku.com"
      assert_equal 302, last_response.status
      assert_match "https://devcenter.heroku.com",
        last_response.headers["Location"]
    end

    it "doesn't redirect to a given url if it's not safe" do
      delete "/logout", url: "https://example.com"
      assert_equal 302, last_response.status
      assert_match %r{/login$}, last_response.headers["Location"]
    end
  end
end
