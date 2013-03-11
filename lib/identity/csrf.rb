module Identity
  class CSRF < ::Rack::Csrf
    def initialize(app, opts={})
      opts.merge!(raise: true)
      super(app, opts)
    end

    def call(env)
      super(env)
    rescue InvalidCsrfToken
      req = Rack::Request.new(env)
      Identity.log :invalid_csrf_token,
        actual_token: req.params['_csrf'],
        expected_token: env['rack.session']['csrf.token'],
        id: env["REQUEST_IDS"].join(",")
      [403, {'Content-Type' => 'text/html', 'Content-Length' => '0'}, []]
    end
  end
end
