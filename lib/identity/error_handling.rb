module Identity
  module ErrorHandling
    UNAVAILABLE_ERRORS = [
      Excon::Errors::ServerError,
      # a NotAcceptable probably means that the ELB has lost its backends and
      # doesn't know how to respond to our V3 "Accept"; display unavailable
      Excon::Errors::NotAcceptable,
      Excon::Errors::ServiceUnavailable,
      Excon::Errors::SocketError,
      Excon::Errors::Timeout
    ]

    def self.registered(app)
      app.error(Excon::Errors::TooManyRequests) do
        e = env["sinatra.error"]
        Identity.log(:exception, type: :too_many_requests,
          class: e.class.name, message: e.message,
          request_id: request.env["REQUEST_IDS"])
        status 429
        slim :"errors/429", layout: :"layouts/purple"
      end

      app.error(*UNAVAILABLE_ERRORS) do
        e = env["sinatra.error"]
        Identity.log(:exception, type: :unavailable,
          class: e.class.name, message: e.message,
          request_id: request.env["REQUEST_IDS"], backtrace: e.backtrace.inspect)
        status 503
        slim :"errors/503", layout: :"layouts/purple"
      end

      app.error Excon::Errors::Unauthorized do
        e = env["sinatra.error"]
        Identity.log(:exception, type: :unauthorized,
          class: e.class.name, message: e.message,
          request_id: request.env["REQUEST_IDS"], backtrace: e.backtrace.inspect)
        status 401
        slim :"errors/401", layout: :"layouts/purple"
      end

      app.error Excon::Errors::NotFound do
        e = env["sinatra.error"]
        Identity.log(:exception, type: :not_found,
          class: e.class.name, message: e.message,
          request_id: request.env["REQUEST_IDS"], backtrace: e.backtrace.inspect)
        status 404
        slim :"errors/404", layout: :"layouts/purple"
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
        Rollbar.error(e, context)
        slim :"errors/500", layout: :"layouts/purple"
      end
    end

    def route(verb, path, *)
      condition { env["HTTP_X_ROUTE_SIGNATURE"] = path.to_s }
      super
    end
  end
end
