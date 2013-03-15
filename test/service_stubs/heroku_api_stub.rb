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

  post "/auth/reset_password" do
    MultiJson.encode({
      message: <<-eos
Check your inbox for the next steps.
If you don't receive an email, and it's not in your spam folder, this could mean you signed up with a different address.
      eos
    })
  end

  get "/auth/finish_reset_password/:hash" do |hash|
    MultiJson.encode({ email: "kerry@heroku.com" })
  end

  post "/auth/finish_reset_password/:hash" do |hash|
    MultiJson.encode({ email: "kerry@heroku.com" })
  end

  get "/oauth/authorizations" do
    status(200)
    MultiJson.encode([])
  end

  post "/oauth/authorizations" do
    authorized!
    status(201)
    MultiJson.encode({
      id:         "authorization123@heroku.com",
      scope:      "all",
      created_at: Time.now,
      updated_at: Time.now,
      access_tokens: [],
      client: {
        id:           123,
        name:         "dashboard",
        redirect_uri: "https://dashboard.heroku.com/oauth/callback/heroku",
      },
      grants: [
        {
          code:       "454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
          expires_in: 300,
        }
      ],
      refresh_tokens: []
    })
  end

  get "/oauth/clients/:id" do |id|
    status(200)
    MultiJson.encode({
      id:           id,
      name:         "An OAuth Client",
      description:  "This is a sample OAuth client rendered by the API stub.",
      redirect_uri: "https://example.com/oauth/callback/heroku",
      trusted:      true,
    })
  end

  post "/oauth/sessions" do
    status(201)
    MultiJson.encode({
      id:          "session123@heroku.com",
      description: "Session @ 127.0.0.1",
      expires_in:  2592000,
    })
  end

  delete "/oauth/sessions/:id" do |id|
    status(200)
    MultiJson.encode({
      id: id,
      description: "Session @ 127.0.0.1",
      expires_in: 2592000,
    })
  end

  post "/oauth/tokens" do
    status(201)
    MultiJson.encode({
      authorization: {
        id: "authorization123@heroku.com",
      },
      access_token: {
        id:         "access-token123@heroku.com",
        token:      "e51e8a64-29f1-4bbf-997e-391d84aa12a9",
        expires_in: 7200,
      },
      refresh_token: {
        id:         "refresh-token123@heroku.com",
        token:      "faa180e4-5844-42f2-ad66-0c574a1dbed2",
        expires_in: 2592000,
      },
      session: {
        id:         "session123@heroku.com",
      },
      user: {
        session_nonce: "0a80ac35-b9d8-4fab-9261-883bea77ad3a",
      }
    })
  end

  post "/signup" do
    MultiJson.encode({ email: "kerry@heroku.com" })
  end

  get "/signup/accept2/:id/:hash" do
    MultiJson.encode({
      created_at: Time.now.iso8601,
      email:      "kerry@heroku.com",
      id:         123,
      invited_by: {
        email: "anna@heroku.com",
      }
    })
  end

  post "/invitation2/save" do
    MultiJson.encode({
      email: "kerry@heroku.com",
      signup_source: {
        redirect_uri: "https://dashboard.heroku.com"
      }
    })
  end
end

if __FILE__ == $0
  $stdout.sync = $stderr.sync = true
  HerokuAPIStub.run! port: ENV["PORT"]
end
