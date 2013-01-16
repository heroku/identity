require "multi_json"
require "sinatra/base"
require "sinatra/namespace"

class HerokuAPIStub < Sinatra::Base
  register Sinatra::Namespace

  configure do
    set :raise_errors,    true
    set :show_exceptions, false
  end

  helpers do
    def auth
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
    end

    def auth_credentials
      auth.provided? && auth.basic? ? auth.credentials : nil
    end

    def authorized!
      halt(401, "Unauthorized") unless auth_credentials
    end
  end

  post "/signup" do
    MultiJson.encode({ email: "kerry@heroku.com" })
  end

  namespace "/auth" do
    post "/reset_password" do
      MultiJson.encode({
        message: <<-eos
Check your inbox for the next steps.
If you don't receive an email, and it's not in your spam folder, this could mean you signed up with a different address.
        eos
      })
    end

    get "/finish_reset_password/:hash" do |hash|
      MultiJson.encode({ email: "kerry@heroku.com" })
    end

    post "/finish_reset_password/:hash" do |hash|
      MultiJson.encode({ email: "kerry@heroku.com" })
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

if __FILE__ == $0
  $stdout.sync = $stderr.sync = true
  HerokuAPIStub.run! port: ENV["PORT"]
end
