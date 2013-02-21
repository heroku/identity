module Identity
  Main = Rack::Builder.new do
    use Rack::Instruments
    use Rack::SSL if Config.production?

    # general cookie storing information of the logged in user; should be
    # scoped to the app's specific domain
    use Rack::Session::Cookie,
      coder: FernetCookieCoder.new(Config.cookie_encryption_key),
      domain: Config.cookie_domain,
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
