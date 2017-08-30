module Identity::Helpers
  module Auth
    include Log
    include API

    # Performs the authorization step of the OAuth dance against the Heroku
    # API.
    def authorize(params, confirm=false)
      api = Identity::HerokuAPI.new(
        pass: @cookie.access_token,
        ip: request.ip,
        request_ids: request_ids,
        version: 3,
        headers: {
          # must ask for legacy IDs to get `legacy_id` field below
          "X-Heroku-Legacy-Ids" => "true"
        })

      client_id = params["client_id"]
      halt 400, "Need client_id" if client_id.nil? || client_id.empty?

      res = log :get_client, client_id: client_id do
        api.get(path: "/oauth/clients/#{client_id}", expects: 200)
      end
      client = MultiJson.decode(res.body)

      # if the account is set to delinquent, and the client does not ignore
      # delinquency, then redirect to the pay-balance page, which is given to
      # us in the `Location` header
      if res.headers["Heroku-Delinquent"] == "true" &&
        !client["ignores_delinquent"]
        redirect to(res.headers["Location"])
      end

      # if the client is not trusted, then see if the user has already
      # authorized it
      if !client["trusted"]
        res = log :get_authorizations do
          api.get(path: "/oauth/authorizations", expects: [200, 401],
            headers: { "Range" => "id ..; max=1000" })
        end

        logout if res.status == 401
        authorizations = MultiJson.decode(res.body)

        authorization = authorizations.detect { |a|
          a["client"] &&
          a["client"]["id"] == client_id &&
          a["scope"] == (params["scope"] || ["global"])
        }

        # fall back to legacy_id (for now)
        if !authorization
          authorization = authorizations.detect { |a|
            a["client"] &&
            a["client"]["legacy_id"] &&
            a["client"]["legacy_id"] == client_id &&
            a["scope"] == (params["scope"] || ["global"])
          }
          if authorization
            log(:legacy_client_id, client_id: authorization["client"]["id"])
          end
        end

        # if there is no authorization raise an error so that we can show a
        # confirmation dialog to the user
        #
        # SECURITY NOTE: the confirm parameter is *only* respected if the
        # request came in on a POST, otherwise a CSRF attack is possible
        if !authorization && (!confirm || request.request_method != "POST")
          raise Identity::Errors::UnauthorizedClient.new(client)
        end
      end

      res = log :create_authorization, by_proxy: true,
        client_id: params["client_id"], session_id: @cookie.session_id do
          api.post(path: "/oauth/authorizations", expects: [201, 401],
            body: MultiJson.encode({
              client:        { id: params["client_id"] },
              scope:         params["scope"],
              response_type: params["response_type"],
              session:       { id: @cookie.session_id },
            }))
      end

      logout if res.status == 401

      # successful authorization, clear any params in session
      @cookie.authorize_params = nil

      authorization = MultiJson.decode(res.body)

      redirect_params = { code: authorization["grant"]["code"] }
      redirect_params.merge!(state: params["state"]) if params["state"]
      uri = build_uri(authorization["client"]["redirect_uri"], redirect_params)
      log :redirecting, uri: uri
      redirect to(uri)
    end

    # merges extra params into a base URI
    def build_uri(base, params)
      uri        = URI.parse(base)
      uri_params = Rack::Utils.parse_query(uri.query).merge(params)
      uri.query  = Rack::Utils.build_query(uri_params)
      uri.to_s
    end

    # Performs the complete OAuth dance against the Heroku API in order to
    # provision an identity client token that can be used by Identity to manage
    # the user's client identities.
    def perform_oauth_dance(user, pass, otp_code)
      log :oauth_dance do
        options = {
          headers:     {},
          ip:          request.ip,
          pass:        pass,
          request_ids: request_ids,
          user:        user,
          version:     3,
        }

        if otp_code
          options[:headers].merge!({ "Heroku-Two-Factor-Code" => otp_code })
        end

        api  = Identity::HerokuAPI.new(options)
        auth = nil

        begin
          res = log :create_authorization, user: user do
            api.post(path: "/oauth/authorizations", expects: 201,
              body: MultiJson.encode({
                client:         { id: Identity::Config.heroku_oauth_id },
                create_session: true,
                create_tokens:  true,
                response_type:  "code",
              }))
          end

          auth = MultiJson.decode(res.body)
        end

        write_authentication_to_cookie auth

        log :oauth_dance_complete, session_id: @cookie.session_id, user: user
      end
    end

    # Attempts to refresh a user's access token using a known refresh token.
    def perform_oauth_refresh_dance
      log :oauth_refresh_dance do
        res = log :refresh_token do
          api = Identity::HerokuAPI.new(ip: request.ip,
            request_ids: request_ids, version: 3)
          api.post(path: "/oauth/tokens", expects: 201,
            body: MultiJson.encode({
              client:        { secret: Identity::Config.heroku_oauth_secret },
              grant:         { type:   "refresh_token" },
              refresh_token: { token:  @cookie.refresh_token },
            }))
        end

        # store appropriate tokens to session
        token = MultiJson.decode(res.body)

        @cookie.access_token            = token["access_token"]["token"]
        @cookie.access_token_expires_at =
          Time.now.getlocal + token["access_token"]["expires_in"]

        raise "missing=access_token"  unless @cookie.access_token
        raise "missing=expires_in"    unless @cookie.access_token_expires_at

        log :oauth_refresh_dance_complete, session_id: @cookie.session_id
      end
    end

    # Attempt to resolve an oauth/authorize request
    def call_authorize(authorize_params = get_authorize_params)
      # clear anything that might be left over in the session
      @cookie.authorize_params = nil

      begin
        # Try to perform an access token refresh if we know it's expired. At
        # the time of this writing, refresh tokens last 30 days (much longer
        # than the short-lived 2 hour access tokens).
        if Time.now.getlocal > @cookie.access_token_expires_at
          perform_oauth_refresh_dance
        end

        # redirects back to the oauth client on success
        authorize(authorize_params, params[:authorize] == "Allow")
      # given client_id wasn't found (API throws a 400 status)
      rescue Excon::Errors::BadRequest
        flash[:error] = "Unknown OAuth client."
        redirect to("/login")
      # we couldn't track the user's session meaning that it's likely been
      # destroyed or expired, redirect to login
      rescue Excon::Errors::NotFound
        redirect to("/login")
      # user needs to login.
      rescue Identity::Errors::LoginRequired
        flash[:link_account] = true
        @cookie.post_signup_url = request.url
        @cookie.authorize_params = authorize_params
        redirect to("/login")
      # refresh token dance was unsuccessful
      rescue Excon::Errors::Unauthorized
        @cookie.authorize_params = authorize_params
        redirect to("/login")
      rescue Identity::Errors::PasswordExpired => e
        flash[:error] = e.message
        redirect to("/account/password/reset")
      rescue Identity::Errors::SuspendedAccount => e
        flash[:error] = e.message
        redirect to("/login")
      # client not yet authorized; show the user a confirmation dialog
      rescue Identity::Errors::UnauthorizedClient => e
        @cookie.authorize_params = authorize_params
        @client = e.client
        @scope  = @cookie && @cookie.authorize_params["scope"] || nil
        slim :"clients/authorize", layout: :"layouts/purple"
      # for example, "invalid scope"
      rescue Excon::Errors::UnprocessableEntity => e
        flash[:error] = decode_error(e.response.body)
        redirect to("/login")
      end
    end

    def filter_params(*safe_params)
      safe_params.flatten!
      params.dup.keep_if { |k, _| safe_params.include?(k) }
    end

    def get_authorize_params
      # if the user is submitting a confirmation form, pull from session,
      # otherwise get params from the request
      if params[:authorize]
        @cookie.authorize_params || {}
      else
        filter_params(%w{client_id response_type scope state prompt}).tap do |p|
          if scope = p["scope"]
            scope = scope.split(",") if String === scope
            p["scope"] = scope.sort.uniq
          end
        end
      end
    end

    def client_deny_url
      base = @client && @client["redirect_uri"] || "https://id.heroku.com"
      build_uri(base, error: "access_denied")
    end

    def write_authentication_to_cookie(auth)
      expires_at = Time.now.getlocal + auth["access_token"]["expires_in"]
      @cookie.session_id              = auth["session"]["id"]
      @cookie.access_token            = auth["access_token"]["token"]
      @cookie.access_token_expires_at = expires_at
      @cookie.refresh_token           = auth["refresh_token"].try(:[], "token")
      @cookie.user_id                 = auth["user"]["id"]
      @cookie.user_email              = auth["user"]["email"]
      @cookie.user_full_name          = auth["user"]["full_name"]

      @cookie.sso_entity = if Identity::Config.sso_base_url
                             auth["sso_entity"]
                           end

      # some basic sanity checks
      raise "missing=access_token"  unless @cookie.access_token
      raise "missing=expires_in"    unless @cookie.access_token_expires_at
    end

    def destroy_session
      return if @cookie.session_id.nil?
      api = Identity::HerokuAPI.new(
        user:        nil,
        pass:        @cookie.access_token,
        ip:          request.ip,
        request_ids: request_ids,
        version:     3
      )
      # tells API to destroy the session for Identity's current tokens, and
      # all the tokens that were provisioned through this session
      log :destroy_session, session_id: @cookie.session_id do
        api.delete(
          path:    "/oauth/sessions/#{@cookie.session_id}",
          expects: [200, 401, 404]
        )
      end
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
  end
end
