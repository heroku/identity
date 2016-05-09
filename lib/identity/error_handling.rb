module Identity
  module ErrorHandling
    UNAVAILABLE_ERRORS = [
      Excon::Errors::ServerError,
      # a NotAcceptable probably means that the ELB has lost its backends and
      # doesn't know how to respond to our V3 "Accept"; display unavailable
      Excon::Errors::NotAcceptable,
      Excon::Errors::ServiceUnavailable,
      Excon::Errors::GatewayTimeout,
      Excon::Errors::SocketError,
      Excon::Errors::Timeout
    ]

    ERROR_TYPES = {
      401 => :unauthorized,
      404 => :not_found,
      429 => :too_many_requests,
      500 => :server_error,
      503 => :unavailable
    }

    def self.registered(app)
      app.helpers Helpers

      app.error Excon::Errors::TooManyRequests do
        handle_error 429
      end

      app.error *UNAVAILABLE_ERRORS do
        handle_error 503
      end

      app.error Excon::Errors::Unauthorized do
        handle_error 401
      end

      app.error Excon::Errors::NotFound do
        handle_error 404
      end

      app.error do
        Rollbar.error(env["sinatra.error"], context)
        handle_error 500
      end
    end

    module Helpers
      def context
        {
          method:          request.request_method,
          module:          self.class.name,
          request_id:      env["REQUEST_IDS"],
          route_signature: env["HTTP_X_ROUTE_SIGNATURE"]
        }
      end

      def handle_error(code)
        status code
        e = env["sinatra.error"]

        Identity.log(:exception, {
          type: ERROR_TYPES[code],
          class: e.class.name,
          message: e.message,
          backtrace: e.backtrace.inspect
        }.merge(context))

        slim :"errors/#{code}", layout: :"layouts/purple"
      end
    end

    def route(verb, path, *)
      condition { env["HTTP_X_ROUTE_SIGNATURE"] = path.to_s }
      super
    end
  end
end
