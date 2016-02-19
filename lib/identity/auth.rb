module Identity
  class Auth < Sinatra::Base
    register ErrorHandling
    register HerokuCookie
    register Sinatra::Namespace

    include Helpers::API
    include Helpers::Auth
    include Helpers::Log

    configure do
      set :views, "#{Config.root}/views"
    end

    before do
      @cookie = Cookie.new(env["rack.session"])
      @oauth_dance_id = request.cookies["oauth_dance_id"]
    end

    namespace "/login" do
      get do
        @campaign = "login" # used to identify the user if they signup from here
        @link_account = flash[:link_account] && @cookie.authorize_params
        if @link_account
          client_id = @cookie.authorize_params["client_id"]
          @oauth_client = get_client_info(client_id)
          @campaign     = get_client_campaign(client_id)
          if @oauth_client["trusted"]
            @link_account = false
          end
        end
        slim :login, layout: :"layouts/purple"
      end

      get "/two-factor" do
        if @cookie.email && @cookie.password
          @sms_number = fetch_sms_number
          slim :"two-factor", layout: :"layouts/purple"
        else
          redirect to("/login")
        end
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

          # in special cases, we may have a redirect URL to go to after login
          if @cookie.redirect_url
            redirect to(@cookie.redirect_url)
          # if we know that we're in the middle of an authorization attempt,
          # continue it; otherwise go to dashboard
          elsif @cookie.authorize_params
            authorize(@cookie.authorize_params)
          else
            redirect to(Config.dashboard_url)
          end
        # given client_id wasn't found (API throws a 400 status)
        rescue Excon::Errors::BadRequest
          flash[:error] = "Unknown OAuth client."
          redirect to("/login")
        # we couldn't track the user's session meaning that it's likely been
        # destroyed or expired, redirect to login
        rescue Excon::Errors::NotFound
          # clear a bad set of parameters in the session
          @cookie.authorize_params = nil
          redirect to("/login")
        # two-factor auth is required
        rescue Excon::Errors::Forbidden => e
          if e.response.headers.has_key?("Heroku-Two-Factor-Required")
            @cookie.email    = user
            @cookie.password = pass
            redirect to("/login/two-factor")
          else
            flash[:error] = decode_error(e.response.body)
            redirect to("/login")
          end
        # oauth dance or post-dance authorization was unsuccessful
        rescue Excon::Errors::Unauthorized
          flash[:error] = "There was a problem with your login."
          redirect to("/login")
        rescue Excon::Errors::TooManyRequests
          flash[:error] = "Account reached login rate limit, please wait a few minutes before trying again"
          redirect to("/login")
        rescue Identity::Errors::PasswordExpired => e
          flash[:error] = e.message
          redirect to("/account/password/reset")
        rescue Identity::Errors::SuspendedAccount => e
          flash[:error] = e.message
          redirect to("/login")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          @scope  = @cookie && @cookie.authorize_params["scope"] || nil
          slim :"clients/authorize", layout: :"layouts/purple"
        # catch-all for generic 4xx errors
        rescue Excon::Errors::ClientError => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/login")
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
          destroy_session
        ensure
          logout
        end
      end
    end

    namespace "/oauth" do
      # OAuth 2 spec stipulates that the authorize endpoint MUST support GET
      # (but that also means be very wary of CSRF):
      #
      #     http://tools.ietf.org/html/rfc6749#section-3.1
      get "/authorize" do
        redirect_or_authorize
      end

      if Identity::Config.development?
        get "/authorize/dev" do
          @client = {"name" => "Test Client"}
          @scope = [
            "create-apps",
            "global",
            "identity",
            "read",
            "read-protected",
            "write",
            "write-protected",
          ]
          slim :"clients/authorize", layout: :"layouts/purple"
        end
      end

      # Tries to authorize a user for a client by proxying the authorization
      # request to API. If the user is not logged in, they are sent to the
      # login screen, from where this authorization will be reattempted on a
      # successful login. If Identity's access token has expired, it is
      # refreshed.
      post "/authorize" do
        redirect_or_authorize
      end

      # Exchanges a code and client_secret for a token set by proxying the
      # request to the API.
      post "/token" do
        begin
          res = log :create_token, by_proxy: true,
            session_id: @cookie.session_id do
            Rack::Auth::Basic::Request.new(request.env)
            # no credentials are required here because the code segment of the
            # exchange is state that's linked to a user in the API
            api = HerokuAPI.new(ip: request.ip, request_ids: request_ids,
              version: 3)
            api.post(path: "/oauth/tokens", expects: 201,
              body: MultiJson.encode({
                client: {
                  secret: client_secret
                },
                grant: {
                  code: params[:code],
                  type: params[:grant_type] || "authorization_code",
                },
                refresh_token: {
                  token: params[:refresh_token]
                },
              }))
          end

          token = MultiJson.decode(res.body)

          content_type(:json)
          status(200)
          response = {
            # core spec response
            access_token:  token["access_token"]["token"],
            expires_in:    token["access_token"]["expires_in"],
            refresh_token: token["refresh_token"]["token"],
            token_type:    "Bearer",

            # heroku extra response
            user_id:       token["user"]["id"],
            session_nonce: token["session"].try(:[], "id")
          }

          # some basic sanity checks
          raise "missing=access_token"  unless response[:access_token]
          raise "missing=expires_in"    unless response[:expires_in]
          raise "missing=refresh_token" unless response[:refresh_token]

          # WARNING: some users appear to have nil nonces
          #raise "missing=session_nonce" unless response[:session_nonce]

          MultiJson.encode(response)
        # Handle 4xx errors from API
        rescue Identity::Errors::SuspendedAccount => e
          content_type(:json)
          [403, e.message]
        # catch-all for generic 4xx errors
        rescue Excon::Errors::ClientError => e
          # pass the whole API error through to the client
          content_type(:json)
          [e.response.status, e.response.body]
        end
      end
    end

    private

    def redirect_or_authorize
      if @cookie.sso_entity && Config.sso_base_url
        # If the user is using SSO, have them auth with the SSO service
        @cookie.authorize_params = get_authorize_params
        redirect to("#{Config.sso_base_url}/#{@cookie.sso_entity}")
      elsif !@cookie.access_token || params[:prompt] == "login"
        # Have users login if they don't have a session, or the client
        # has requested an explicit login
        flash[:link_account] = true
        @cookie.post_signup_url = request.url
        @cookie.authorize_params = get_authorize_params
        redirect to("/login")
      else
        # Otherwise, perform the authorization
        call_authorize
      end
    end

    def flash
      request.env["x-rack.flash"]
    end

    def client_secret
      # per RFC 6749 section 2.3.1, token endpoint must accept basic auth
      req = Rack::Auth::Basic::Request.new(request.env)
      if req.provided? && req.basic?
        # credentials contain the client ID (user) and the client secret (pass)
        _, client_secret = req.credentials
        client_secret
      else
        # if it's not is basic auth, hopefully it's in the request body
        params[:client_secret]
      end
    end

    def get_client_info(client_id)
      api = HerokuAPI.new(ip: request.ip, version: 3)
      res = api.get(
        expects: 200,
        path: "/oauth/clients/#{client_id}")
      MultiJson.decode(res.body)
    end

    # hardcoded for now :{ we can potentially move this to API at some point,
    # but will need some sort of service to issue salesforce campaign ids
    def get_client_campaign(oauth_client_id)
      {
        Identity::Config.parse_oauth_client_id => "parse",
      }[oauth_client_id] || "login"
    end

    def logout
      url = if params[:url] && safe_redirect?(params[:url])
              params[:url]
            else
              "/login"
            end

      @cookie.clear
      redirect to(url)
    end

    def safe_redirect?(url)
      uri = URI.parse(url)
      # possibly move this to a config var if it starts ballooning out of
      # control
      [
        "addons.heroku.com",
        "addons-staging.heroku.com",
        "api.heroku.com",
        "api.staging.herokudev.com",
        "devcenter.heroku.com",
        "devcenter-staging.heroku.com",
        "discussion.heroku.com",
        "discussion-staging.heroku.com",
      ].include?(uri.host)
    rescue URI::InvalidURIError
      false
    end
  end
end
