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
          # on return to V3, change to just expect 201
          api.post(path: "/oauth/authorizations", expects: [200, 201, 401],
            query: params.merge(session_id: @cookie.session_id))
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

    def delete_heroku_cookie(key)
      response.delete_cookie(key,
        domain: heroku_cookie_domain)
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

        # create a session on which we can group any authorization grants and
        # tokens which will be created during this Identity, err, session
        res = log :create_session do
          # on return to V3, change to just expect 201
          api.post(path: "/oauth/sessions", expects: 201)
        end
        session = MultiJson.decode(res.body)
        @cookie.session_id = session["id"]

        res = log :create_authorization do
          # on return to V3, change to just expect 201
          api.post(path: "/oauth/authorizations", expects: [200, 201],
            query: {
              client_id:     Config.heroku_oauth_id,
              response_type: "code",
              session_id:    @cookie.session_id,
            })
        end

        grant_code = MultiJson.decode(res.body)["grants"][0]["code"]

        # exchange authorization grant code for an access/refresh token set
        res = log :create_token do
          # on return to V3, change to just expect 201
          api.post(path: "/oauth/tokens", expects: [200, 201],
            query: {
              code:          grant_code,
              client_secret: Config.heroku_oauth_secret,
              grant_type:    "authorization_code",
            })
        end

        # store appropriate tokens to session
        token = MultiJson.decode(res.body)

        # on return to V3, remove || onwards (except for nonce)
        @cookie.access_token            =
          token["access_token"]["token"] || token["access_token"]
        @cookie.access_token_expires_at =
          Time.now +
            (token["access_token"]["expires_in"] || token["expires_in"])
        @cookie.refresh_token           =
           token["refresh_token"]["token"] || token["refresh_token"]
        nonce =
          (token["session_nonce"] || token["user"]["session_nonce"] rescue nil)

        # some basic sanity checks
        raise "missing=access_token"  unless @cookie.access_token
        raise "missing=expires_in"    unless @cookie.access_token_expires_at
        raise "missing=refresh_token" unless @cookie.refresh_token
        #raise "missing=session_nonce" unless nonce

        # cookies with a domain scoped to all heroku domains, used to set a
        # session nonce value so that consumers can recognize when the logged
        # in user has changed
        set_heroku_cookie("heroku_session", "1")
        set_heroku_cookie("heroku_session_nonce", nonce)

        log :oauth_dance_complete, session_id: @cookie.session_id, nonce: nonce
      end
    end

    # Attempts to refresh a user's access token using a known refresh token.
    def perform_oauth_refresh_dance
      log :oauth_refresh_dance do
        res = log :refresh_token do
          api = HerokuAPI.new(user: nil, pass: @cookie.access_token,
            request_ids: request_ids)
          # on return to V3, change to just expect 201
          api.post(path: "/oauth/tokens", expects: [200, 201],
            query: {
              client_secret: Config.heroku_oauth_secret,
              grant_type:    "refresh_token",
              refresh_token: @cookie.refresh_token,
            })
        end

        # store appropriate tokens to session
        token = MultiJson.decode(res.body)

        # on return to V3, eliminate all clauses to the left of ||
        @cookie.access_token            =
          token["access_token"] || token["access_token"]["token"]
        @cookie.access_token_expires_at =
          Time.now + (token["expires_in"] || token["access_token"]["expires_in"])

        raise "missing=access_token"  unless @cookie.access_token
        raise "missing=expires_in"    unless @cookie.access_token_expires_at
      end
    end

    def set_heroku_cookie(key, value)
      response.set_cookie(key,
        domain:    heroku_cookie_domain,
        http_only: true,
        max_age:   2592000,
        value:     value)
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
  end
end
