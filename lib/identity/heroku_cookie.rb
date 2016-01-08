module Identity
  # This extension helps with set/unset logic for the infamous Heroku cookie
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
  module HerokuCookie
    def self.registered(app)
      app.instance_eval do
        include Helpers::Log
        include Methods
      end

      app.after do
        if @cookie && @cookie.session_id
          set_heroku_cookie(headers, "heroku_session", "1")
          set_heroku_cookie(headers, "heroku_session_nonce", @cookie.session_id)
          set_heroku_cookie(headers, "heroku_user_session", encrypted_user_info)

          log :write_heroku_cookie,
            nonce: @cookie.session_id,
            oauth_dance_id: request.cookies["oauth_dance_id"]
        else
          delete_heroku_cookie(headers, "heroku_session")
          delete_heroku_cookie(headers, "heroku_session_nonce")
          delete_heroku_cookie(headers, "heroku_user_session")

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
          path:   "/",
        )
      end

      def set_heroku_cookie(headers, key, value)
        Rack::Utils.set_cookie_header!(headers, key,
          domain:  Config.heroku_cookie_domain,
          expires: Time.now + Config.cookie_expire_after,
          path:    "/",
          value:   value
        )
      end

      private

      def user_info
        {
          user: {
            id: @cookie.user_id, email: @cookie.user_email, full_name: @cookie.user_full_name
          }
        }
      end

      def encrypted_user_info
        cookie_coder.encode(user_info)
      end

      def cookie_coder
        @cookie_coder ||= CookieCoder.new(
          Config.heroku_root_domain_cookie_encryption_key,
          Config.old_heroku_root_domain_cookie_encryption_key
        )
      end
    end
  end
end
