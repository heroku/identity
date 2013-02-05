module Identity
  # Helps to store general data that we expect to be in our session.
  module SessionHelpers
    def access_token
      @access_token ||= session["access_token"]
    end

    def access_token=(token)
      @access_token = token
      session["access_token"] = token
    end

    def access_token_expires_at
      @access_token_expires_at ||=
        Time.parse(session["access_token_expires_at"])
    end

    def access_token_expires_at=(expires_at)
      @access_token_expires_at = expires_at
      session["access_token_expires_at"] =
        expires_at ? expires_at.iso8601 : nil
    end

    def authorize_params
      @authorize_params ||= session["authorize_params"] ?
        MultiJson.decode(session["authorize_params"]) : nil
    end

    def authorize_params=(params)
      @authorize_params = params
      session["authorize_params"] = params ? MultiJson.encode(params) : nil
    end

    def refresh_token
      @refresh_token ||= session["refresh_token"]
    end

    def refresh_token=(token)
      @refresh_token = token
      session["refresh_token"] = token
    end

    def session_id
      # session_id is a reserved key
      @session_id ||= session["oauth_session_id"]
    end

    def session_id=(id)
      @session_id = id
      # session_id is a reserved key
      session["oauth_session_id"] = id
    end

    def signup_source
      @signup_source ||= session["signup_source"]
    end

    def signup_source=(slug)
      @signup_source = slug
      session["signup_source"] = slug
    end

    #
    # Heroku
    #

    # session that's scoped to all Heroku domains
    def heroku_session
      env["rack.session.heroku"] ||= {}
    end

    def heroku_session_nonce
      @heroku_session_nonce ||= heroku_session["heroku_session_nonce"]
    end

    def heroku_session_nonce=(nonce)
      @heroku_session_nonce = nonce
      heroku_session["heroku_session_nonce"] = nonce
    end
  end
end
