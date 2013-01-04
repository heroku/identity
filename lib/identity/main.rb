module Identity
  Main = Rack::Builder.new do
    use Rack::Instruments
    use Rack::SSL if Config.production?
    use Rack::Session::Cookie, path: '/',
                               expire_after: 2592000,
                               secret: Config.secure_key
    use Rack::Csrf
    use Rack::Flash

    run Sinatra::Router.new {
      mount Identity::Assets
      run Identity::Web
    }
  end
end
