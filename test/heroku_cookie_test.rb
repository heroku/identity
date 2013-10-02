require_relative "test_helper"

describe Identity::HerokuCookie do
  it "sets the Heroku cookie when appropriate" do
    app = middleware(-> (env) {
      env["heroku.cookie"] = { "nonce" => "1234" }
      [200, {}, {}]
    })
    _, headers, _ = app.call({})
    assert_includes headers["Set-Cookie"], "heroku_session=1;"
    assert_includes headers["Set-Cookie"], "heroku_session_nonce=1234;"
  end

  it "deletes the Heroku cookie when appropriate" do
    app = middleware(-> (env) {
      [200, {}, {}]
    })
    _, headers, _ = app.call({})
    assert_includes headers["Set-Cookie"], "heroku_session=;"
    assert_includes headers["Set-Cookie"], "heroku_session_nonce=;"
  end

  it "persists the Heroku cookie through a standard request" do
    cookie = cookies_for_nonce("1234")

    app = middleware(-> (env) {
      [200, {}, {}]
    })
    _, headers, _ = app.call({ "HTTP_COOKIE" => cookie })
    assert_includes headers["Set-Cookie"], "heroku_session=1;"
    assert_includes headers["Set-Cookie"], "heroku_session_nonce=1234;"
  end

  private

  def cookies_for_nonce(nonce)
    app = middleware(-> (env) {
      env["heroku.cookie"] = { "nonce" => nonce }
      [200, {}, {}]
    })
    _, headers, _ = app.call({})

    # Rack will separate multiple `Set-Cookie` headers with a newline; grab the
    # key=value from all of these; then combine them back together with a
    # semicolon for injection back in via `Cookie` on request
    cookies = headers["Set-Cookie"].split("\n")
    cookies.map { |c| c.split(";")[0] }.join(";")
  end

  def middleware(app)
    Identity::HerokuCookie.new(
      app,
      domain: "example.com",
      expire_after: 2592000,
      key: "heroku.cookie"
    )
  end
end
