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
      it "raises unauthorized if it can't find a matching authorization" do
        stub_heroku_client_requests(get_authorizations: [])

        assert_raises Identity::Errors::UnauthorizedClient do
          authorize
        end
      end

      it "succedes if it can find a matching authorization" do
        stub_heroku_client_requests

        authorize

        assert_equal 302, last_response.status
        assert_equal "http://example.com/foo?code=abc", last_response.headers["Location"]
      end

      # it "handles 206 responses from GET /oauth/authorizations" do
      #   auth_params[:client_id] = '123'
      #   # auths are on two pages
      #   response = get_authorizations_response * 1001
      #   # matching auth is on the 2nd page
      #   response.last[:client][:id] = '123'
      #   stub_heroku_client_requests(get_authorizations: response)
      #
      #   authorize
      #
      #   assert_equal 302, last_response.status
      #   assert_equal "http://example.com/foo?code=abc", last_response.headers["Location"]
      # end
    end
  end

  private

  def authorize
    get "/auth",
      {grant_type: "authorization_code", code: "secret-auth-grant-code"},
      rack_env
  end

  let(:get_client_response) do
    {
      trusted: false,
      redirect_uri: "https://example.com"
    }
  end

  let(:get_authorizations_response) do
    [{
      client: {
        id: "12345678-abcd-1234-abcd-1234567890ab"
      },
      scope: ["global"]
    }]
  end

  let(:post_authorizations_response) do
    {
      client: {
        redirect_uri: "http://example.com/foo",
      },
      grant: {
        code: "abc",
      }
    }
  end

  def stub_heroku_client_requests(get_client:          get_client_response,
                                  get_authorizations:  get_authorizations_response,
                                  post_authorizations: post_authorizations_response)
    stub_heroku_api do
      get "/oauth/clients/:id" do
        MultiJson.encode(get_client)
      end

      get "/oauth/authorizations" do
        # paginate!
        if get_authorizations.count > 1000
          status(206)
        end
        MultiJson.encode(get_authorizations)
      end

      post "/oauth/authorizations" do
        status(201)
        MultiJson.encode(post_authorizations)
      end
    end
  end

end
