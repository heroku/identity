module Identity
  class Auth < Sinatra::Base
    include SessionHelpers
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
    end

    namespace "/sessions" do
      get "/new" do
        slim :"sessions/new"
      end

      post do
        begin
          user, pass = params[:email], params[:password]
          perform_oauth_dance(user, pass)

          # if we know that we're in the middle of an authorization attempt,
          # continue it; otherwise go to dashboard
          if authorize_params
            authorize(authorize_params)
          else
            redirect to(Config.dashboard_url)
          end
        # oauth dance or post-dance authorization was unsuccessful
        rescue Excon::Errors::Forbidden
          flash[:error] = "There was a problem with your login."
          redirect to("/sessions/new")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          @authorize_params = authorize_params
          self.authorize_params = authorize_params
          slim :"clients/authorize"
        end
      end

      delete do
        session.clear
        redirect to("/sessions/new")
      end
    end

    namespace "/oauth" do
      get "/authorize" do
        # same as POST
        call(env.merge("REQUEST_METHOD" => "POST"))
      end

      post "/authorize" do
        authorize_params =
          filter_params(%w{client_id response_type scope state})
        begin
          # have the user login if we have no session for them
          if !self.access_token
            self.authorize_params = authorize_params
            redirect to("/sessions/new")
          end

          # Try to perform an access token refresh if we know it's expired. At
          # the time of this writing, refresh tokens last 30 days (much longer
          # than the short-lived 2 hour access tokens).
          if Time.now > self.access_token_expires_at
            perform_oauth_refresh_dance
          end

          # redirects back to the oauth client on success
          authorize(authorize_params, params[:authorize] == "Authorize")
        # refresh token dance was unsuccessful
        rescue Excon::Errors::Forbidden
          self.authorize_params = authorize_params
          redirect to("/sessions/new")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          @params = authorize_params
          self.authorize_params = authorize_params
          slim :"clients/authorize"
        end
      end

      post "/token" do
        res = log :create_token, by_proxy: true do
          api = HerokuAPI.new(user: nil, request_id: request_id)
          api.post(path: "/oauth/tokens", expects: 200,
            query: { code: params[:code], client_secret: params[:client_secret] })
        end
        token = MultiJson.decode(res.body)

        content_type(:json)
        status(200)
        MultiJson.encode({
          # core spec response
          "access_token"  => token["access_token"]["access_token"],
          "expires_in"    => token["access_token"]["expires_in"],
          "refresh_token" => token["refresh_token"]["refresh_token"],
          "token_type"    => "Bearer",

          # heroku extra response
          "session_nonce" => token["session_nonce"],
        })
      end
    end

    private

    # Performs the authorization step of the OAuth dance against the Heroku
    # API.
    def authorize(params, confirm=false)
      api = HerokuAPI.new(user: nil, pass: self.access_token,
        request_id: request_id)

      res = log :get_client, client_id: params["client_id"] do
        api.get(path: "/oauth/clients/#{params["client_id"]}", expects: 200)
      end
      client = MultiJson.decode(res.body)

      # if the client is not trusted, then see if the user has already
      # authorized it
      if !client["trusted"]
        res = log :get_authorizations do
          api.get(path: "/oauth/authorizations", expects: 201)
        end
        authorizations = MultiJson.decode(res.body)

        authorization = authorizations.
          detect { |a| a["client"]["id"] == params["client_id"] }

        # if there is no authorization raise an error so that we can show a
        # confirmation dialog to the user
        if !authorization && !confirm
          raise Identity::Errors::UnauthorizedClient.new(client)
        end
      end

      res = log :create_authorization, by_proxy: true,
        client_id: params["client_id"] do
          api.post(path: "/oauth/authorizations", expects: 201, query: params)
      end

      # successful authorization, clear any params in session
      self.authorize_params = nil

      authorization = MultiJson.decode(res.body)

      redirect_params = { code: authorization["grants"][0]["code"] }
      redirect_params.merge!(state: params["state"]) if params["state"]
      base_uri = authorization["client"]["redirect_uri"]
      redirect to(build_uri(base_uri, redirect_params))
    end

    # merges extra params into a base URI
    def build_uri(base, params)
      uri        = URI.parse(base)
      uri_params = Rack::Utils.parse_query(uri.query).merge(params)
      uri.query  = Rack::Utils.build_query(uri_params)
      uri.to_s
    end

    def filter_params(*safe_params)
      safe_params.flatten!
      params.dup.keep_if { |k, v| safe_params.include?(k) }
    end

    def flash
      request.env["x-rack.flash"]
    end

    def log(action, data={}, &block)
      data.merge! id: request_id
      Slides.log(action, data.merge(data), &block)
    end

    # Performs the complete OAuth dance against the Heroku API in order to
    # provision a user token that can be used by Identity to manage the user's
    # client identities.
    def perform_oauth_dance(user, pass)
      log :oauth_dance do
        api = HerokuAPI.new(user: user, pass: pass, request_id: request_id)
        res = log :create_authorization do
          api.post(path: "/oauth/authorizations", expects: 201,
            query: { client_id: Config.heroku_oauth_id, response_type: "code" })
        end

        code = MultiJson.decode(res.body)["grants"][0]["code"]

        # exchange authorization code for access grant
        res = log :create_token do
          api.post(path: "/oauth/tokens", expects: 200,
            query: {
              code:          code,
              client_secret: Config.heroku_oauth_secret,
              grant_type:    "authorization_code",
            })
        end

        # store appropriate tokens to session
        token = MultiJson.decode(res.body)
        self.access_token            = token["access_token"]["token"]
        self.access_token_expires_at =
          Time.now + token["access_token"]["expires_in"]
        self.refresh_token           = token["refresh_token"]["token"]
      end
    end

    # Attempts to refresh a user's access token using a known refresh token.
    def perform_oauth_refresh_dance
      log :oauth_refresh_dance do
        res = log :refresh_token do
          api.post(path: "/oauth/tokens", expects: 200,
            query: {
              client_secret: Config.heroku_oauth_secret,
              grant_type:    "refresh_token",
              refresh_token: refresh_token,
            })
        end

        # store appropriate tokens to session
        token = MultiJson.decode(res.body)
        self.access_token            = token["access_token"]["token"]
        self.access_token_expires_at =
          Time.now + token["access_token"]["expires_in"]
      end
    end

    def request_id
      request.env["REQUEST_ID"]
    end
  end
end
