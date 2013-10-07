module Identity::Middleware
  # This middleware helps with set/unset logic for the infamous Heroku cookie
  # used by Identity and other Heroku properties. The purpose of the Heroku
  # cookie is to set a general cookie available on the `.heroku.com` domain
  # that helps signal to other properties that the current user is logged in.
  #
  # A tiny bit of historical info: this started out as just `heroku_session`
  # which is just a simple boolean. It was eventually expanded to
  # `heroku_session_nonce` where a unique nonce value for the current user is
  # stored; other properties can observe the nonce value for changes to quickly
  # determine whether or not the logged in user has changed since the last time
  # the browser visited.
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
        delete_cookie(headers, "heroku_session")
        delete_cookie(headers, "heroku_session_nonce")
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
