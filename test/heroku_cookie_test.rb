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

  private

  def middleware(app)
    Identity::HerokuCookie.new(
      app,
      domain: "example.com",
      expire_after: 2592000,
      key: "heroku.cookie"
    )
  end
end
