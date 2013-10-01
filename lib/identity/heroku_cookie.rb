module Identity
  class HerokuCookie
    def initialize(app, opts={})
      @app = app

      @domain       = opts[:domain] || raise("missing=domain")
      @expire_after = opts[:expire_after]
      @key          = opts[:key] || raise("missing=key")
    end

    def call(env)
      request = Rack::Request.new(env)
      if nonce = request.cookies["heroku_session_nonce"]
        env[@key] = {
          "nonce" => nonce
        }
      end

      status, headers, response = @app.call(env)

      if env[@key]
        set_cookie(headers, "heroku_session", "1")
        set_cookie(headers, "heroku_session_nonce", env[@key]["nonce"])
      else
        %w(heroku_session heroku_session_nonce).each do |key|
          delete_cookie(headers, key)
        end
      end

      [status, headers, response]
    end

    private

    def delete_cookie(headers, key)
      Rack::Utils.delete_cookie_header!(headers, key,
        domain: @domain,
      )
    end

    def set_cookie(headers, key, value)
      Rack::Utils.set_cookie_header!(headers, key,
        domain:  @domain,
        expires: @expire_after ? Time.now + @expire_after : nil,
        value:   value
      )
    end
  end
end
