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

    def two_factor?
      user = auth_credentials.first
      !env['HTTP_HEROKU_TWO_FACTOR_CODE'] && user.start_with?('two')
    end
  end

  before do
    @body = MultiJson.decode(request.body.read) rescue {}
  end

  post "/auth/reset_password" do
    MultiJson.encode({
      message: <<-eos
Check your inbox for the next steps.
If you don't receive an email, and it's not in your spam folder, this could mean you signed up with a different address.
      eos
    })
  end

  get "/auth/finish_reset_password/:token" do |token|
    MultiJson.encode({ email: "kerry@heroku.com" })
  end

  post "/auth/finish_reset_password/:token" do |token|
    MultiJson.encode({ email: "kerry@heroku.com" })
  end

  patch "/users/~" do
    authorized!
    200
  end

  get "/oauth/authorizations" do
    status(200)
    MultiJson.encode([])
  end

  post "/oauth/authorizations" do
    authorized!

    if two_factor?
      status(403)
      response.headers['Heroku-Two-Factor-Required'] = 'true'
      return MultiJson.encode(
        message: 'A second factor is required.',
        id: 'two_factor'
      )
    end

    status(201)

    authorization = {
      id:         "68e3146b-be7e-4520-b60b-c4f06623084f",
      scope:      ["global"],
      created_at: Time.now,
      updated_at: Time.now,
      access_token: nil,
      client: {
        id:                 123,
        ignores_delinquent: false,
        name:               "dashboard",
        redirect_uri:       "https://dashboard.heroku.com/oauth/callback/heroku",
      },
      grant: {
          code:       "454118bc-902d-4a2c-9d5b-e2a2abb91f6e",
          expires_in: 300,
      },
      refresh_token: nil,
      user: {
        id: "06dcaabe-f7cd-473a-aa10-df54045ff69c"
      },
    }

    if @body["create_session"]
      authorization.merge!(
        session: { id: "8bb579ed-e3a4-41ed-9c1c-719e96618f71" })
    end

    if @body["create_tokens"]
      authorization.merge!(
        access_token: {
          id:         "access-token123@heroku.com",
          token:      "e51e8a64-29f1-4bbf-997e-391d84aa12a9",
          expires_in: 7200,
        },
        refresh_token: {
          id:         "refresh-token123@heroku.com",
          token:      "faa180e4-5844-42f2-ad66-0c574a1dbed2",
          expires_in: 2592000
        })
    end

    MultiJson.encode(authorization)
  end

  get "/oauth/clients/:id" do |id|
    parse_oauth_client = "e780a170-f68f-46d2-99fd-a9878d8e6c75"
    status(200)
    MultiJson.encode({
      id:                 id,
      name:               "An OAuth Client",
      description:        "This is a sample OAuth client rendered by the API stub.",
      ignores_delinquent: false,
      redirect_uri:       "https://example.com/oauth/callback/heroku",
      trusted:            id != parse_oauth_client,
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
        id: "68e3146b-be7e-4520-b60b-c4f06623084f",
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
        id:         "8bb579ed-e3a4-41ed-9c1c-719e96618f71",
      },
      user: {
        session_nonce: "0a80ac35-b9d8-4fab-9261-883bea77ad3a",
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

  get "/users/~/sms-number" do
    authorized!

    MultiJson.encode({
      sms_number: two_factor? ? '+1 *** 1234' : nil,
    })
  end

  post "/users/~/sms-number/actions/recover" do
    status(201)
  end
end

if __FILE__ == $0
  $stdout.sync = $stderr.sync = true
  HerokuAPIStub.run! port: ENV["PORT"]
end
