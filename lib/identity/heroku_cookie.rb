module Identity
  module HerokuCookie
    KEY = "heroku.cookie"

    def self.registered(app)
      app.instance_eval do
        include Helpers::Log
        include Methods
      end

      app.before do
        if nonce = request.cookies["heroku_session_nonce"]
          env[KEY] = {
            "nonce" => nonce
          }
        end

        log :read_heroku_cookie,
          nonce: env[KEY] ? env[KEY]["nonce"] : "unset",
          oauth_dance_id: request.cookies["oauth_dance_id"]
      end

      app.after do
        if env[KEY]
          set_heroku_cookie(headers, "heroku_session", "1")
          set_heroku_cookie(headers, "heroku_session_nonce", env[KEY]["nonce"])

          log :write_heroku_cookie,
            nonce: env[KEY]["nonce"],
            oauth_dance_id: request.cookies["oauth_dance_id"]
        else
          delete_heroku_cookie(headers, "heroku_session")
          delete_heroku_cookie(headers, "heroku_session_nonce")

          log :delete_heroku_cookie,
            oauth_dance_id: request.cookies["oauth_dance_id"]
        end
      end
    end

    private

    module Methods
      def delete_heroku_cookie(headers, key)
        Rack::Utils.delete_cookie_header!(headers, key,
          domain: Config.heroku_cookie_domain,
        )
      end

      def set_heroku_cookie(headers, key, value)
        Rack::Utils.set_cookie_header!(headers, key,
          domain:  Config.heroku_cookie_domain,
          expires: Time.now + Config.cookie_expire_after,
          value:   value
        )
      end
    end
  end
end
