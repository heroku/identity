module Identity
  Main = Rack::Builder.new do
    use Identity::Instruments, context: { app: "identity" }
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
