require_relative "test_helper"

describe Identity::CSRF do
  include Rack::Test::Methods

  def app
    Sinatra.new do
      use Rack::Session::Cookie, domain: "example.org", secret: "my-secret"
      use Identity::CSRF

      get "/good" do
        200
      end

      get "/bad" do
        raise Rack::Csrf::InvalidCsrfToken
      end
    end
  end

  it "falls through normally" do
    get "/good"
    assert_equal 200, last_response.status
  end

  it "responds with a 403 on a bad CSRF request" do
    get "/bad"
    assert_equal 403, last_response.status
  end

  it "logs certain request information" do
    mock(Identity).log(:invalid_csrf_token, anything)
    get "/bad"
  end
end
