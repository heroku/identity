module Identity
  module ErrorHandling
    def self.registered(app)
      app.error do
        e = env["sinatra.error"]
        Airbrake.notify(e) if Config.airbrake_api_key
        Identity.log(:exception, class: e.class.name, message: e.message)
        slim :"errors/500", layout: :"layouts/classic"
      end
    end
  end
end
