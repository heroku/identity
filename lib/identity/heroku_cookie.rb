module Identity
  class HerokuCookie
    def initialize(session)
      @session = session
    end

    # still used by Devcenter + Help to determine whether the user is logged in
    def active=(value)
      @session["heroku_session"] = value
    end

    def clear
      @session.clear
    end

    def nonce
      @heroku_session_nonce ||= @session["heroku_session_nonce"]
    end

    def nonce=(nonce)
      @nonce = nonce
      @session["heroku_session_nonce"] = nonce
    end
  end
end
