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
      stub(Identity::Config).finalize_shared_secret { nil }
    end

    it "returns 404" do
      get "/login/extenal?token=123"
      assert_equal 404, last_response.status
    end
  end

  describe "shared key is configured" do
    let(:shared_key){ "hello world secret token" }

    before do
      stub(Identity::Config).finalize_shared_secret { shared_key }
    end

    it "returns 401 if token is incorrect" do
      get "/login/external?token=123"
      assert_equal 401, last_response.status
    end

    describe "token is correct" do
      let(:cookie_data){{ "foo" => "bar" }}
      let(:token){ JWT.encode(cookie_data, shared_key, "HS256") }

      it "writes cookies and redirects to dashboard" do
        any_instance_of(Identity::LoginExternal) do |finalize|
          mock(finalize).write_authentication_to_cookie(cookie_data)
        end

        get "/login/external?token=#{token}"

        assert_equal 302, last_response.status
        assert_equal Identity::Config.dashboard_url, last_response.headers["Location"]
      end
    end
  end
end
