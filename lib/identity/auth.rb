module Identity
  class Auth < Sinatra::Base
    register ErrorHandling
    register Sinatra::Namespace

    include AuthHelpers
    include LogHelpers

    configure do
      set :views, "#{Config.root}/views"
    end

    before do
      @cookie = Cookie.new(session)
    end

    namespace "/login" do
      get do
        slim :login, layout: :"layouts/zen_backdrop"
      end

      get "/two-factor" do
        slim :"two-factor", layout: :"layouts/zen_backdrop"
      end

      # Creates a session for a user by receiving their username and password.
      # If that user was trying to authorize an OAuth client before being
      # forced to login, that authorization process is continued.
      post do
        begin
          if code = params[:code]
            user, pass = @cookie.email, @cookie.password
          else
            user, pass = params[:email], params[:password]
          end

          perform_oauth_dance(user, pass, code)

          # if we know that we're in the middle of an authorization attempt,
          # continue it; otherwise go to dashboard
          if @cookie.authorize_params
            authorize(@cookie.authorize_params)
          else
            redirect to(Config.dashboard_url)
          end
        # given client_id wasn't found
        rescue Excon::Errors::NotFound
          flash[:error] = "Unknown OAuth client."
          redirect to("/login")
        # two-factor auth is required
        rescue Excon::Errors::Forbidden => e
          raise e unless e.response.headers.has_key?("Heroku-Two-Factor-Required")
          @cookie.email    = user
          @cookie.password = pass
          redirect to("/login/two-factor")
        # oauth dance or post-dance authorization was unsuccessful
        rescue Excon::Errors::Unauthorized
          flash[:error] = "There was a problem with your login."
          redirect to("/login")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          slim :"clients/authorize", layout: :"layouts/zen_backdrop"
        end
      end
    end

    namespace "/logout" do
      get do
        # same as DELETE
        call(env.merge("REQUEST_METHOD" => "DELETE"))
      end

      delete do
        begin
          api = HerokuAPI.new(user: nil, pass: @cookie.access_token,
            request_ids: request_ids)
          # tells API to destroy the session for Identity's current tokens, and
          # all the tokens that were provisioned through this session
          log :destroy_session, session_id: @cookie.session_id do
            api.delete(path: "/oauth/sessions/#{@cookie.session_id}",
              expects: [200, 401])
          end
        ensure
          logout
        end
      end
    end

    namespace "/oauth" do
      get "/authorize" do
        # same as POST
        call(env.merge("REQUEST_METHOD" => "POST"))
      end

      # Tries to authorize a user for a client by proxying the authorization
      # request to API. If the user is not logged in, they are sent to the
      # login screen, from where this authorization will be reattempted on a
      # successful login. If Identity's access token has expired, it is
      # refreshed.
      post "/authorize" do
        # if the user is submitting a confirmation form, pull from session,
        # otherwise get params from the request
        authorize_params = params[:authorize] ? (@cookie.authorize_params || {}) :
          filter_params(%w{client_id response_type scope state})

        begin
          # have the user login if we have no session for them
          raise Identity::Errors::NoSession if !@cookie.access_token

          # Try to perform an access token refresh if we know it's expired. At
          # the time of this writing, refresh tokens last 30 days (much longer
          # than the short-lived 2 hour access tokens).
          if Time.now > @cookie.access_token_expires_at
            perform_oauth_refresh_dance
          end

          # redirects back to the oauth client on success
          authorize(authorize_params, params[:authorize] == "Allow Access")
        # given client_id wasn't found
        rescue Excon::Errors::NotFound
          flash[:error] = "Unknown OAuth client."
          redirect to("/login")
        # refresh token dance was unsuccessful
        rescue Excon::Errors::Unauthorized, Identity::Errors::NoSession
          @cookie.authorize_params = authorize_params
          redirect to("/login")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          @cookie.authorize_params = authorize_params
          slim :"clients/authorize", layout: :"layouts/zen_backdrop"
        end
      end

      # Exchanges a code and client_secret for a token set by proxying the
      # request to the API.
      post "/token" do
        res = log :create_token, by_proxy: true, session_id: @cookie.session_id do
          # no credentials are required here because the code segment of the
          # exchange is state that's linked to a user in the API
          api = HerokuAPI.new(user: nil, request_ids: request_ids)
          api.post(path: "/oauth/tokens", expects: 201, query: {
            code:          params[:code],
            client_secret: params[:client_secret],
            grant_type:    "authorization_code",
            session_id:    @cookie.session_id,
          })
        end

        token = MultiJson.decode(res.body)

        content_type(:json)
        status(200)
        MultiJson.encode({
          # core spec response
          access_token:  token["access_token"]["token"],
          expires_in:    token["access_token"]["expires_in"],
          refresh_token: token["refresh_token"]["token"],
          token_type:    "Bearer",

          # heroku extra response
          session_nonce: token["session_nonce"],
        })
      end
    end

    private

    def filter_params(*safe_params)
      safe_params.flatten!
      params.dup.keep_if { |k, v| safe_params.include?(k) }
    end

    def flash
      request.env["x-rack.flash"]
    end

    def logout
      @cookie.clear

      # clear heroku globally-scoped cookies
      response.delete_cookie("heroku_session")
      response.delete_cookie("heroku_session_nonce")

      url = if params[:url] && safe_redirect?(params[:url])
        params[:url]
      else
        "/login"
      end
      redirect to(url)
    end

    def safe_redirect?(url)
      uri = URI.parse(url)
      # possibly move this to a config var if it starts ballooning out of
      # control
      [
        "addons.heroku.com",
        "addons-staging.heroku.com",
        "devcenter.heroku.com",
        "devcenter-staging.heroku.com",
      ].include?(uri.host)
    rescue URI::InvalidURIError
      false
    end
  end
end
