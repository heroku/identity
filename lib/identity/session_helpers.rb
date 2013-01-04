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
      session["authorize_params"] = MultiJson.encode(params)
    end
  end
end
