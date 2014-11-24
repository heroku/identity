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
        slim :"errors/503", layout: :"layouts/purple"
      end

      app.error do
        e = env["sinatra.error"]
        context = {
          method:          request.request_method,
          module:          self.class.name,
          request_id:      env["REQUEST_IDS"],
          route_signature: env["HTTP_X_ROUTE_SIGNATURE"],
          session_id:      @cookie ? @cookie.session_id : nil,
          user_id:         @cookie ? @cookie.user_id : nil,
        }
        Identity.log(:exception, {
          class: e.class.name,
          message: e.message,
          backtrace: e.backtrace.inspect
        }.merge(context))
        Honeybadger.notify(e, context: context) if Config.honeybadger_api_key
        slim :"errors/500", layout: :"layouts/purple"
      end
    end

    def route(verb, path, *)
      condition { env["HTTP_X_ROUTE_SIGNATURE"] = path.to_s }
      super
    end
  end
end
