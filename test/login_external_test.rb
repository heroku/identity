require_relative "test_helper"

describe Identity::Account do
  include Rack::Test::Methods

  def app
    Rack::Builder.new do
      use Rack::Session::Cookie, domain: "example.org", secret: "my-secret"
      run Identity::LoginExternal
    end
  end

  def request_session
    last_request.env["rack.session"]
  end

  before do
    rack_mock_session.clear_cookies
  end

  describe "shared key is not configured" do
    before do
      stub(Identity::Config).login_external_secret { nil }
    end

    it "returns 404" do
      get "/login/extenal?token=123"
      assert_equal 404, last_response.status
    end
  end

  describe "shared key is configured" do
    let(:shared_key){ "hello world secret token" }

    before do
      stub(Identity::Config).login_external_secret { shared_key }
    end

    it "returns 401 if token is incorrect" do
      get "/login/external?token=123"
      assert_equal 401, last_response.status
    end

    describe "token is correct" do
      let(:jwt_data) { { "foo" => "bar" } }
      let(:token) { JWT.encode(jwt_data, shared_key, "HS256") }

      describe "there is no active oauth authorization request" do
        it "writes cookies and redirects to dashboard" do
          any_instance_of(Identity::LoginExternal) do |finalize|
            mock(finalize).write_authentication_to_cookie(jwt_data)
          end

          get "/login/external?token=#{token}"

          assert_equal 302, last_response.status
          assert_equal Identity::Config.dashboard_url,
                       last_response.headers["Location"]
        end
      end

      describe "the user has an active oauth authorization request" do
        before do
          stub_heroku_api
        end

        let(:jwt_data) do
          { access_token: { token: "abcd", expires_in: 9000 },
            session: { id: "456" },
            user: { id: "123" },
            sso_entity: "initech" }
        end

        let(:session_data) do
          { "authorize_params" => MultiJson.encode("client_id" => "dashboard") }
        end

        it "finishes the authorization" do
          get "/login/external",
              { token: token },
              "rack.session" => session_data

          assert_equal 302, last_response.status
          assert_equal "https://dashboard.heroku.com/oauth/callback/" \
                       "heroku?code=454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
                       last_response.headers["Location"]
        end
      end

      describe "existing sessions" do
        let(:session_id) { "1234" }
        let(:rack_env) do
          {
            "rack.session" => {
              "oauth_session_id" => session_id, "access_token" => "5678"
            }
          }
        end

        it "clears an existing session" do
          session_deleted = false

          stub_heroku_api do
            delete "/oauth/sessions/:id" do
              session_deleted = true
              status 200
            end
          end

          any_instance_of(Identity::LoginExternal) do |finalize|
            mock(finalize).write_authentication_to_cookie(jwt_data)
          end

          get "/login/external?token=#{token}", {}, rack_env

          assert_equal 302, last_response.status
          assert session_deleted, "old session must be deleted"
          assert_match /^heroku_user_session=(.+)$/, response_cookie,
                       "it should contain a new session"
          refute_match /^heroku_user_session=#{session_id}$/, response_cookie,
                       "it should not contain the old session"
        end
      end
    end
  end

  private

  def response_cookie
    last_response.headers["Set-Cookie"]
  end
end
