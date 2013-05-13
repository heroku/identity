module Identity
  module ErrorHandling
    UNAVAILABLE_ERRORS = [
      Excon::Errors::BadGateway,
      # a NotAcceptable probably means that the ELB has lost its backends and
      # doesn't know how to respond to our V3 "Accept"; display unavailable
      Excon::Errors::NotAcceptable,
      Excon::Errors::ServiceUnavailable,
      Excon::Errors::SocketError,
      Excon::Errors::Timeout,
    ]

    def self.registered(app)
      app.error *UNAVAILABLE_ERRORS do
        e = env["sinatra.error"]
        Identity.log(:exception, type: :unavailable,
          class: e.class.name, message: e.message,
          request_id: request.env["REQUEST_IDS"], backtrace: e.backtrace.inspect)
        slim :"errors/503", layout: :"layouts/classic"
      end

      app.error do
        e = env["sinatra.error"]
        Airbrake.notify(e) if Config.airbrake_api_key
        Identity.log(:exception,
          class: e.class.name, message: e.message,
          request_id: request.env["REQUEST_IDS"], backtrace: e.backtrace.inspect)
        slim :"errors/500", layout: :"layouts/classic"
      end
    end
  end
end
