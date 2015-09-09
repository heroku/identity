require_relative "../test_helper"

describe Identity::Helpers::Auth do
  include Rack::Test::Methods

  let(:auth_params) { { client_id: "12345678-abcd-1234-abcd-1234567890ab" } }
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
    before do
    end

    it "halts if client_id was not supplied" do
      auth_params[:client_id] = nil
      get "/auth", {}, rack_env
      assert_equal 400, last_response.status
      assert_equal "Need client_id", last_response.body
    end
  end

end
