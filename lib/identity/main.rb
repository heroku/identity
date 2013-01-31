module Identity
  Main = Rack::Builder.new do
    use Rack::Instruments
    use Rack::SSL if Config.production?

    # general cookie storing information of the logged in user; should be
    # scoped to the app's specific domain
    use Rack::Session::Cookie, domain: Config.cookie_domain,
                               path: '/',
                               expire_after: 2592000,
                               secret: Config.secure_key

    # cookie with a domain scoped to all heroku domains, used to set a session
    # nonce value so that consumers can recognize when the logged in user has
    # changed
    if Config.heroku_cookie_domain
      use Rack::Session::Cookie, domain: Config.heroku_cookie_domain,
                                 expire_after: 2592000,
                                 key: 'rack.session.heroku',
                                 secret: Config.secure_key
    end

    use Rack::Csrf, skip: ["POST:/oauth/.*"]
    use Rack::Flash

    run Sinatra::Router.new {
      mount Identity::Account
      mount Identity::Assets
      mount Identity::Auth
      run Sinatra.new {
        get "/" do
          redirect to("/login")
        end

        not_found do
          "fml"
        end
      }
    }
  end
end
