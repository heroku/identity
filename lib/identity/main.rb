module Identity
  Main = Rack::Builder.new do
    use Rack::Instruments,
      context: { app: "identity" },
      response_request_id: true
    use Rack::SSL if Config.production?
    use Rack::Deflater

    # General cookie storing information of the logged in user; don't set the
    # domain so that it's allowed to default to the current app's domain scope.
    use Rack::Session::Cookie,
      coder: FernetCookieCoder.new(
        Config.cookie_encryption_key,
        Config.old_cookie_encryption_key),
      http_only: true,
      path: '/',
      expire_after: 2592000
    use Middleware::HerokuCookie,
      domain: Config.heroku_cookie_domain,
      expire_after: 2592000,
      key: "heroku.cookie"

    # CSRF + Flash should come before the unadorned heroku cookies that follow
    use Identity::CSRF, skip: ["POST:/login", "POST:/oauth/.*"]
    use Rack::Flash

    run Sinatra::Router.new {
      mount Account
      mount Assets
      mount Auth
      run   Default # index + error handlers
    }
  end
end
