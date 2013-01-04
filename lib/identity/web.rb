module Identity
  class Web < Sinatra::Base
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
    end

    namespace "/sessions" do
      get do
        slim :"sessions/new"
      end

      post do
        user, pass = params[:email], params[:password]
        session[:token] = perform_oauth_dance(user, pass)

        # if we know that we're in the middle of an authorization attempt,
        # continue it; otherwise go to dashboard
        if session["authorize_params"]
          authorize(MultiJson.decode(session["authorize_params"]))
        else
          redirect to(Config.dashboard_url)
        end
      end

      delete do
        session.clear
        redirect to("/sessions")
      end
    end

    namespace "/oauth" do
      post "/authorize" do
        authorize_params =
          filter_params(%w{client_id respond_type scope state})

        # have the user login if we have no session for them or if we know
        # they're past their token's expiry
        if !session[:token] || Time.now > session[:token][:expires_at]
          store_authorize_params_and_login(authorize_params)
        end

        # redirects back to the oauth client on success
        authorize(authorize_params)
      end

      post "/token" do
        redirect to("/sessions") if !session[:token]
        res = api.post(path: "/oauth/token", expects: 200,
          query: { code: params[:code], client_secret: params[:client_secret] })
        content_type(:json)
        [200, res.body]
      end
    end

    private

    def api
      @api ||= HerokuAPI.new(user: nil, pass: session[:token][:access_token])
    end

    def authorize(params)
      res = api.post(path: "/oauth/authorize",
        expects: [200, 401], query: params)
      store_authorize_params_and_login(params) if res.status == 401

      # successful authorization, clear any params in session
      session["authorize_params"] = nil

      authorization = MultiJson.decode(res.body)

      redirect_params = { code: authorization["code"] }
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

    def perform_oauth_dance(user, pass)
      api = HerokuAPI.new(user: user, pass: pass)
      res = api.post(path: "/oauth/authorize", expects: [200, 401],
        query: { client_id: Config.heroku_oauth_id })

      if res == 401
        flash[:notice] = "Login failed!"
        redirect to("/sessions")
      end

      code = MultiJson.decode(res.body)["code"]

      # exchange authorization code for access grant
      res = api.post(path: "/oauth/token", expects: 200,
        query: { code: code, client_secret: Config.heroku_oauth_secret })

      token = MultiJson.decode(res.body)
      { access_token:  token["access_token"],
        expires_at:    Time.now + token["expires_in"],
        refresh_token: token["refresh_token"],
        session_nonce: token["session_nonce"] }
    end

    def store_authorize_params_and_login(params)
      session["authorize_params"] = MultiJson.encode(params)
      redirect to("/sessions")
    end
  end
end
