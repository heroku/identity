require_relative "../test_helper"

describe Identity::Helpers::Auth do
  include Rack::Test::Methods

  let(:client_id)   { "12345678-abcd-1234-abcd-1234567890ab" }
  let(:auth_params) { { client_id: client_id } }
  let(:rack_env) do
    {
      "rack.session" => { "authorize_params" => MultiJson.encode(auth_params) }
    }
  end

  def app
    Sinatra.new do
      use Rack::Session::Cookie, domain: "example.org", secret: "my-secret"
      include Identity::Helpers::Auth

      get "/auth" do
        @cookie = Identity::Cookie.new(env["rack.session"])
        authorize(@cookie.authorize_params)
        200
      end

      def logout
      end
    end
  end

  before do
    stub_heroku_api
  end

  describe :authorize do
    it "halts if client_id was not supplied" do
      auth_params[:client_id] = nil
      authorize
      assert_equal 400, last_response.status
      assert_equal "Need client_id", last_response.body
    end

    describe "untrusted client" do

      let(:authorization) do
        {
          client: {
            id: 123
          },
          scope: ["global"]
        }
      end

      it "raises unauthorized if it can't find a matching authorization" do
        stub_heroku_api do
          get "/oauth/clients/:id" do
            MultiJson.encode({
              trusted: false,
              redirect_uri: "https://example.com"
            })
          end

          get "/oauth/authorizations" do
            MultiJson.encode([])
          end
        end

        assert_raises Identity::Errors::UnauthorizedClient do
          authorize
        end
      end

      it "succedes if it can find a matching authorization" do
        stub_heroku_api do
          get "/oauth/clients/:id" do
            MultiJson.encode({
              trusted: false,
              redirect_uri: "https://example.com"
            })
          end

          get "/oauth/authorizations" do
            MultiJson.encode([{
              client: {
                id: "12345678-abcd-1234-abcd-1234567890ab"
              },
              scope: ["global"]
            }])
          end

          post("/oauth/authorizations") do
            status(201)
            MultiJson.encode({
              client: {
                redirect_uri: "http://example.com/foo",
              },
              grant: {
                code: "abc",
              }
            })
          end
        end

        authorize

        assert_equal 302, last_response.status
        assert_equal "http://example.com/foo?code=abc", last_response.headers["Location"]
      end

    end
  end

  def authorize
    get "/auth",
      {grant_type: "authorization_code", code: "secret-auth-grant-code"},
      rack_env
  end

end
