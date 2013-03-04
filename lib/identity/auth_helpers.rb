module Identity
  module AuthHelpers
    include LogHelpers

    # Performs the authorization step of the OAuth dance against the Heroku
    # API.
    def authorize(params, confirm=false)
      api = HerokuAPI.new(user: nil, pass: @cookie.access_token,
        request_ids: request_ids)

      halt 400, "Need client_id" unless params["client_id"]

      res = log :get_client, client_id: params["client_id"] do
        api.get(path: "/oauth/clients/#{params["client_id"]}", expects: 200)
      end
      client = MultiJson.decode(res.body)

      # if the client is not trusted, then see if the user has already
      # authorized it
      if !client["trusted"]
        res = log :get_authorizations do
          api.get(path: "/oauth/authorizations", expects: [200, 401])
        end

        logout if res.status == 401
        authorizations = MultiJson.decode(res.body)

        authorization = authorizations.
          detect { |a| a["client"] && a["client"]["id"] == params["client_id"] }

        # if there is no authorization raise an error so that we can show a
        # confirmation dialog to the user
        if !authorization && !confirm
          raise Identity::Errors::UnauthorizedClient.new(client)
        end
      end

      res = log :create_authorization, by_proxy: true,
        client_id: params["client_id"], session_id: @cookie.session_id do
          api.post(path: "/oauth/authorizations", expects: [201, 401],
            query: params)
      end

      logout if res.status == 401

      # successful authorization, clear any params in session
      @cookie.authorize_params = nil

      authorization = MultiJson.decode(res.body)

      redirect_params = { code: authorization["grants"][0]["code"] }
      redirect_params.merge!(state: params["state"]) if params["state"]
      uri = build_uri(authorization["client"]["redirect_uri"], redirect_params)
      log :redirecting, uri: uri
      redirect to(uri)
    end

    # Performs the complete OAuth dance against the Heroku API in order to
    # provision an identity client token that can be used by Identity to manage
    # the user's client identities.
    def perform_oauth_dance(user, pass, otp_code)
      log :oauth_dance do
        options = { user: user, pass: pass, request_ids: request_ids }
        if otp_code
          options.merge!(headers: { "Heroku-Two-Factor-Code" => otp_code })
        end
        api = HerokuAPI.new(options)
        res = log :create_authorization do
          api.post(path: "/oauth/authorizations", expects: 201,
            query: { client_id: Config.heroku_oauth_id, response_type: "code" })
        end

        grant_code = MultiJson.decode(res.body)["grants"][0]["code"]

        # exchange authorization grant code for an access/refresh token set
        res = log :create_token do
          api.post(path: "/oauth/tokens", expects: 201,
            query: {
              code:          grant_code,
              client_secret: Config.heroku_oauth_secret,
              grant_type:    "authorization_code",
            })
        end

        # store appropriate tokens to session
        token = MultiJson.decode(res.body)
        @cookie.access_token            = token["access_token"]["token"]
        @cookie.access_token_expires_at =
          Time.now + token["access_token"]["expires_in"]
        @cookie.refresh_token           = token["refresh_token"]["token"]
        @cookie.session_id              = token["session"]["id"]

        # cookies with a domain scoped to all heroku domains, used to set a
        # session nonce value so that consumers can recognize when the logged
        # in user has changed
        set_heroku_cookie("heroku_session", "1")
        set_heroku_cookie("heroku_session_nonce",
          token["user"]["session_nonce"])

        log :oauth_dance_complete, session_id: @cookie.session_id,
          nonce: token["user"]["session_nonce"]
      end
    end

    # Attempts to refresh a user's access token using a known refresh token.
    def perform_oauth_refresh_dance
      log :oauth_refresh_dance do
        res = log :refresh_token do
          api = HerokuAPI.new(user: nil, pass: @cookie.access_token,
            request_ids: request_ids)
          api.post(path: "/oauth/tokens", expects: 201,
            query: {
              client_secret: Config.heroku_oauth_secret,
              grant_type:    "refresh_token",
              refresh_token: @cookie.refresh_token,
            })
        end

        # store appropriate tokens to session
        token = MultiJson.decode(res.body)
        @cookie.access_token            = token["access_token"]["token"]
        @cookie.access_token_expires_at =
          Time.now + token["access_token"]["expires_in"]
      end
    end

    private

    # merges extra params into a base URI
    def build_uri(base, params)
      uri        = URI.parse(base)
      uri_params = Rack::Utils.parse_query(uri.query).merge(params)
      uri.query  = Rack::Utils.build_query(uri_params)
      uri.to_s
    end

    def heroku_cookie_domain
      domain = request.host.split(".")[1..-1].join(".")

      # for something like "localhost", just use the base domain
      domain != "" ? domain : request.host
    end

    def set_heroku_cookie(key, value)
      response.set_cookie(key,
        domain:    heroku_cookie_domain,
        http_only: true,
        max_age:   2592000,
        value:     value)
    end
  end
end
