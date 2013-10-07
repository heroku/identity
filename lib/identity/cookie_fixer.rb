module Identity
  # This is a temporary "fixer" class to resync any account's Identity and
  # Heroku session cookies that have drifted. Under older implementations, the
  # Heroku session cookie's expiry was not updated as often as Identity's, and
  # therefore it was possible it could expire and leave only Identity's session
  # in place, thus confusing other web properties. This fixer will take of that
  # situation.
  #
  # The cookie fixer was added on Oct 7th, 2013. I'm arbitrarily choosing some
  # amount of time, one month, after which we should remove it. Therefore, if
  # you're reading this after Nov 7th, 2013, please strip this class out.
  #
  # For more details:
  #     https://github.com/heroku/identity/pull/72
  module CookieFixer
    def self.registered(app)
      app.instance_eval do
        include Helpers::Log
      end

      app.after do
        if @cookie && @cookie.session_id && !env["heroku.cookie"]
          env["heroku.cookie"] = { "nonce" => @cookie.session_id }
          log :fixed_heroku_cookie, session_id: @cookie.session_id
        end
      end
    end
  end
end
