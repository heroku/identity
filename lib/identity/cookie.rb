module Identity
  class Cookie
    def initialize(session)
      @session = session
    end

    def access_token
      @access_token ||= @session["access_token"]
    end

    def access_token=(token)
      @access_token = token
      @session["access_token"] = token
    end

    def access_token_expires_at
      @access_token_expires_at ||=
        Time.parse(@session["access_token_expires_at"])
    end

    def access_token_expires_at=(expires_at)
      @access_token_expires_at = expires_at
      @session["access_token_expires_at"] =
        expires_at ? expires_at.iso8601 : nil
    end

    def authorize_params
      @authorize_params ||= @session["authorize_params"] ?
        MultiJson.decode(@session["authorize_params"]) : nil
    end

    def authorize_params=(params)
      @authorize_params = params
      @session["authorize_params"] = params ? MultiJson.encode(params) : nil
    end

    def clear
      @session.clear
    end

    # used to store creds during two-factor auth
    def email
      @email ||= @session["email"]
    end

    def email=(password)
      @email = @session["email"]
      @session["email"] = email
    end

    # used to store creds during two-factor auth
    def password
      @password ||= @session["password"]
    end

    def password=(password)
      @password = @session["password"]
      @session["password"] = password
    end

    def refresh_token
      @refresh_token ||= @session["refresh_token"]
    end

    def refresh_token=(token)
      @refresh_token = token
      @session["refresh_token"] = token
    end

    def session_id
      # session_id is a reserved key
      @session_id ||= @session["oauth_session_id"]
    end

    def session_id=(id)
      @session_id = id
      # session_id is a reserved key
      @session["oauth_session_id"] = id
    end

    def signup_source
      @signup_source ||= @session["signup_source"]
    end

    def signup_source=(slug)
      @signup_source = slug
      @session["signup_source"] = slug
    end
  end
end
