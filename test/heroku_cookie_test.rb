require_relative "test_helper"

describe Identity::HerokuCookie do
  include Rack::Test::Methods

  def app
    @app
  end

  it "sets the Heroku cookie when appropriate" do
    @app = new_app({ "nonce" => "1234" })
    get "/"
    assert_includes response_cookie, "heroku_session=1;"
    assert_includes response_cookie, "heroku_session_nonce=1234;"
  end

  it "deletes the Heroku cookie when appropriate" do
    @app = new_app(nil)
    get "/"
    assert_includes response_cookie, "heroku_session=;"
    assert_includes response_cookie, "heroku_session_nonce=;"
  end

  it "persists the Heroku cookie through a standard request" do
    @app = new_app(nil)
    header "Cookie", "heroku_session=1;heroku_session_nonce=1234"
    get "/"
    assert_includes response_cookie, "heroku_session=1;"
    assert_includes response_cookie, "heroku_session_nonce=1234;"
  end

  private

  def new_app(heroku_cookie)
    Sinatra.new do
      register Identity::HerokuCookie

      get "/" do
        if heroku_cookie
          env[Identity::HerokuCookie::KEY] = heroku_cookie
        end
      end
    end
  end

  def response_cookie
    last_response.headers["Set-Cookie"]
  end
end
