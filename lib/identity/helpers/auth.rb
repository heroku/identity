module Identity::Helpers
  module Auth
    include Log

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

      halt 400, "Need client_id" unless params["client_id"]

      res = log :get_client, client_id: params["client_id"] do
        api.get(path: "/oauth/clients/#{params["client_id"]}", expects: 200)
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
          api.get(path: "/oauth/authorizations", expects: [200, 401])
        end

        logout if res.status == 401
        authorizations = MultiJson.decode(res.body)

        authorization = authorizations.detect { |a|
          a["client"] && a["client"]["id"] == params["client_id"] &&
            a["scope"] == (params["scope"] || ["global"])
        }

        # fall back to legacy_id (for now)
        if !authorization
          authorization = authorizations.detect { |a|
            a["client"] && a["client"]["legacy_id"] &&
              a["client"]["legacy_id"] == params["client_id"] &&
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
          res = log :create_authorization do
            api.post(path: "/oauth/authorizations", expects: 201,
              body: MultiJson.encode({
                client:         { id: Identity::Config.heroku_oauth_id },
                create_session: true,
                create_tokens:  true,
                response_type:  "code",
              }))
          end

          auth = MultiJson.decode(res.body)
        rescue Excon::Errors::UnprocessableEntity => e
          err = MultiJson.decode(e.response.body)
          if err['id'] == "suspended"
            raise Identity::Errors::SuspendedAccount.new(err["message"])
          else
            raise e
          end
        end

        @cookie.session_id              = auth["session"]["id"]
        @cookie.access_token            = auth["access_token"]["token"]
        @cookie.access_token_expires_at =
          Time.now + auth["access_token"]["expires_in"]
        @cookie.refresh_token           = auth["refresh_token"]["token"]
        @cookie.user_id                 = auth["user"]["id"]

        # some basic sanity checks
        raise "missing=access_token"  unless @cookie.access_token
        raise "missing=expires_in"    unless @cookie.access_token_expires_at
        raise "missing=refresh_token" unless @cookie.refresh_token

        log :oauth_dance_complete, session_id: @cookie.session_id
      end
    end

    # Attempts to refresh a user's access token using a known refresh token.
    def perform_oauth_refresh_dance
      log :oauth_refresh_dance do
        res = log :refresh_token do
          api = Identity::HerokuAPI.new(pass: @cookie.access_token,
            ip: request.ip, request_ids: request_ids, version: 3)
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
          Time.now + token["access_token"]["expires_in"]

        raise "missing=access_token"  unless @cookie.access_token
        raise "missing=expires_in"    unless @cookie.access_token_expires_at

        log :oauth_refresh_dance_complete, session_id: @cookie.session_id
      end
    end
  end
end
