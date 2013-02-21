module Identity
  Main = Rack::Builder.new do
    use Rack::Instruments
    use Rack::SSL if Config.production?

    # General cookie storing information of the logged in user; don't set the
    # domain so that it's allowed to default to the current app's domain scope.
    use Rack::Session::Cookie,
      coder: FernetCookieCoder.new(Config.cookie_encryption_key),
      http_only: true,
      path: '/',
      expire_after: 2592000

    # CSRF + Flash should come before the unadorned heroku cookies that follow
    use Rack::Csrf, skip: ["POST:/oauth/.*"]
    use Rack::Flash

    run Sinatra::Router.new {
      mount Identity::Account
      mount Identity::Assets
      mount Identity::Auth
      run   Identity::Default # index + error handlers
    }
  end
end
