require_relative "test_helper"

describe Identity::HerokuCookie do
  include Rack::Test::Methods

  def app
    @app
  end

  it "sets the Heroku cookie when appropriate" do
    @app = new_app({ "oauth_session_id" => "1234" })
    get "/"
    assert_includes response_cookie, "heroku_session=1; domain=.heroku.com; path=/;"
    assert_includes response_cookie, "heroku_session_nonce=1234; domain=.heroku.com; path=/;"
  end

  it "deletes the Heroku cookie when appropriate" do
    @app = new_app({})
    get "/"
    assert_includes response_cookie, "heroku_session=; domain=.heroku.com; path=/;"
    assert_includes response_cookie, "heroku_session_nonce=; domain=.heroku.com; path=/;"
  end

  private

  def new_app(cookie)
    Sinatra.new do
      register Identity::HerokuCookie

      get "/" do
        @cookie = Identity::Cookie.new(cookie)
      end
    end
  end

  def response_cookie
    last_response.headers["Set-Cookie"]
  end
end
