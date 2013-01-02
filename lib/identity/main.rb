module Identity
  Main = Rack::Builder.new do
    use Rack::Instruments
    use Rack::SSL if Config.production?

    run Sinatra::Router.new {
      mount Identity::Assets
      run Identity::Web
    }
  end
end
