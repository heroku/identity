class HerokuAPIStub < Sinatra::Base
  register Sinatra::Namespace

  helpers do
    def auth
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
    end

    def auth_credentials
      auth.provided? && auth.basic? ? auth.credentials : nil
    end

    def authorized!
      raise APIError.new(401, "Unauthorized") unless auth_credentials
    end
  end

  namespace "/oauth" do
    post "/authorize" do
      authorized!
      status(200)
      MultiJson.encode({
        id:         "authorization123@heroku.com",
        code:       "454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
        scope:      "all",
        created_at: Time.now,
        updated_at: Time.now,
        client: {
          id:           123,
          name:         "dashboard",
          redirect_uri: "https://dashboard.heroku.com/oauth/callback/heroku",
        }
      })
    end

    post "/token" do
      status(200)
      MultiJson.encode({
        access_token:  "e51e8a64-29f1-4bbf-997e-391d84aa12a9",
        refresh_token: "faa180e4-5844-42f2-ad66-0c574a1dbed2",
        token_type:    "Bearer",
        expires_in:    1234,
        scope:         "all",
        session_nonce: "0a80ac35-b9d8-4fab-9261-883bea77ad3a",
      })
    end
  end
end
