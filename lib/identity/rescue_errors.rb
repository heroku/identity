module Identity
  class RescueErrors
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => e
      Identity.log(:exception, class: e.class.name, message: e.message,
        backtrace: e.backtrace.inspect)
      [500, { 'Content-Type' => 'text/html', 'Content-Length' => '0' }, []]
    end
  end
end
