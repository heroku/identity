module Identity
  class Instruments < Rack::Instruments
    def call(env)
      status, headers, response = super
      headers["Request-Id"] = env["REQUEST_ID"] if env["REQUEST_ID"]
      [status, headers, response]
    end
  end
end
