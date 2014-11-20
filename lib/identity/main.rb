module Identity
  Main = Rack::Builder.new do
    use Identity::RescueErrors
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
      expire_after: Config.cookie_expire_after,
      key: 'identity-session'


    # CSRF + Flash should come before the unadorned heroku cookies that follow
    use Identity::CSRF, skip: [
      # skip CSRF for POST /oauth/token (the second step of a standard OAuth
      # flow)
      "POST:/oauth/.*",

      # skip CSRF for POST /account/accept/ok (where users confirm their account
      # and set their password) so Dev Center can submit this form from a
      # different app and provide a different on-boarding experience.
      # It seems dangerous, but the form can only be used once and needs
      # a unique user_id / token combination to work that is only shared with
      # the user's email address after signing up.
      "POST:/account/accept/ok"
    ]
    use Rack::Flash

    run Sinatra::Router.new {
      mount Account
      mount Assets
      mount Auth
      mount Robots
      run   Default # index + error handlers
    }
  end
end
