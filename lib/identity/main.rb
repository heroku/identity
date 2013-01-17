module Identity
  Main = Rack::Builder.new do
    use Rack::Instruments
    use Rack::SSL if Config.production?
    use Rack::Session::Cookie, #domain: Config.cookie_domain,
                               path: '/',
                               expire_after: 2592000,
                               secret: Config.secure_key
    use Rack::Csrf, skip: ["POST:/oauth/.*"]
    use Rack::Flash

    run Sinatra::Router.new {
      mount Identity::Account
      mount Identity::Assets
      mount Identity::Auth
      run Sinatra.new {
        get "/" do
          redirect to("/sessions/new")
        end

        not_found do
          "fml"
        end
      }
    }
  end
end
