require 'cgi'
require "addressable/uri"

module Identity
  class Account < Sinatra::Base
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

    namespace "/account" do
      # The omniauth strategy used to make a call to /account after a
      # successful authentication, so proxy this through to core.
      # Authentication occurs via a header with a bearer token.
      #
      # Remove this as soon as we get Devcenter and Dashboard upgraded.
      get do
        return 401 if !request.env["HTTP_AUTHORIZATION"]
        api = HerokuAPI.new(user: nil, request_ids: request_ids, version: 2,
          authorization: request.env["HTTP_AUTHORIZATION"],
          # not necessarily V3, respond with whatever the client asks for
          headers: {
            "Accept" => request.env["HTTP_ACCEPT"] || "application/json"
          })
        res = api.get(path: "/account", expects: 200)
        content_type(:json)
        res.body
      end

      post do
        begin
          api = HerokuAPI.new(request_ids: request_ids, version: 2)
          signup_source = generate_referral_slug(@cookie.signup_source)
          res = api.post(path: "/signup", expects: 200,
            body: URI.encode_www_form({
              email: params[:email],
              slug: signup_source
            }))
          json = MultiJson.decode(res.body)
          slim :"account/finish_new", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/signup")
        end
      end

      get "/accept/:id/:hash" do |id, hash|
        begin
          api = HerokuAPI.new(request_ids: request_ids, version: 2)
          res = api.get(path: "/invitation2/show", expects: 200,
            body: URI.encode_www_form({
              "id"    => id,
              "token" => hash,
            }))
          @user = MultiJson.decode(res.body)
          slim :"account/accept", layout: :"layouts/classic"
        # Core should return a 404, but returns a 422
        rescue Excon::Errors::NotFound, Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          slim :login, layout: :"layouts/zen_backdrop"
        end
      end

      post "/accept/:id/:hash" do |id, hash|
        begin
          api = HerokuAPI.new(request_ids: request_ids, version: 2)
          res = api.post(path: "/invitation2/save", expects: 200,
            body: URI.encode_www_form({
              "id"                          => id,
              "token"                       => hash,
              "user[password]"              => params[:password],
              "user[password_confirmation]" => params[:password_confirmation],
              "user[receive_newsletter]"    => params[:receive_newsletter],
            }))
          json = MultiJson.decode(res.body)

          # log the user in right away
          perform_oauth_dance(json["email"], params[:password], nil)

          # if we know that we're in the middle of an authorization attempt,
          # continue it
          if @cookie.authorize_params
            authorize(@cookie.authorize_params)
          # users who signed up from a particular source may have a specialized
          # redirect location; otherwise go to Dashboard
          elsif json["signup_source"]
            redirect to(json["signup_source"]["redirect_uri"])
          elsif slug = json["signup_source_slug"]
            redirect to("#{Config.dashboard_url}/signup/finished?#{slug}")
          else
            redirect to("#{Config.dashboard_url}/signup/finished")
          end
        # given client_id wasn't found
        rescue Excon::Errors::NotFound
          flash[:error] = "Unknown OAuth client or session."
          redirect to("/login")
        # refresh token dance was unsuccessful
        rescue Excon::Errors::Unauthorized
          redirect to("/login")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          slim :"clients/authorize", layout: :"layouts/zen_backdrop"
        # some problem occurred with the signup
        rescue Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/account/accept/#{id}/#{hash}")
        end
      end

      get "/email/confirm/:hash" do |hash|
        begin
          # confirming an e-mail change requires authentication
          raise Identity::Errors::NoSession if !@cookie.access_token
          api = HerokuAPI.new(user: nil, pass: @cookie.access_token,
            request_ids: request_ids, version: 2)
          # currently returns a 302, but will return a 200
          api.post(path: "/confirm_change_email/#{hash}", expects: [200, 302])
          redirect to(Config.dashboard_url)
        # user tried to access the change e-mail request under the wrong
        # account
        rescue Excon::Errors::Forbidden
          flash[:error] = "This link can't be used with your current login."
          redirect to("/login")
        rescue Excon::Errors::NotFound, Excon::Errors::UnprocessableEntity => e
          slim :"account/email/not_found", layout: :"layouts/zen_backdrop"
        # it seems that the user's access token is no longer valid, refresh
        rescue Excon::Errors::Unauthorized
          begin
            perform_oauth_refresh_dance
            redirect to(request.path_info)
          # refresh dance unsuccessful
          rescue Excon::Errors::Unauthorized
            redirect to("/logout")
          end
        rescue Identity::Errors::NoSession
          @cookie.redirect_url = request.env["PATH_INFO"]
          redirect to("/login")
        end
      end

      get "/password/reset" do
        slim :"account/password/reset", layout: :"layouts/zen_backdrop"
      end

      post "/password/reset" do
        begin
          api = HerokuAPI.new(request_ids: request_ids, version: 2)
          res = api.post(path: "/auth/reset_password", expects: 200,
            body: URI.encode_www_form({
              email: params[:email]
            }))

          json = MultiJson.decode(res.body)
          flash.now[:notice] = json["message"]
          slim :"account/password/reset", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::NotFound, Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/account/password/reset")
        end
      end

      get "/password/reset/:hash" do |hash|
        begin
          api = HerokuAPI.new(request_ids: request_ids, version: 2)
          res = api.get(path: "/auth/finish_reset_password/#{hash}",
            expects: 200)

          @user = MultiJson.decode(res.body)
          slim :"account/password/finish_reset", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::NotFound => e
          slim :"account/password/not_found", layout: :"layouts/zen_backdrop"
        end
      end

      post "/password/reset/:hash" do |hash|
        begin
          api = HerokuAPI.new(request_ids: request_ids, version: 2)
          res = api.post(path: "/auth/finish_reset_password/#{hash}",
            expects: 200, body: URI.encode_www_form({
              :password              => params[:password],
              :password_confirmation => params[:password_confirmation],
            }))

          flash[:success] = "Your password has been changed."
          redirect to("/login")
        rescue Excon::Errors::NotFound => e
          slim :"account/password/not_found", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/account/password/reset/#{hash}")
        end
      end
    end

    get "/signup" do
      @cookie.signup_source = params[:slug]
      slim :signup, layout: :"layouts/zen_backdrop"
    end

    get "/signup/:slug" do |slug|
      @cookie.signup_source = slug
      slim :signup, layout: :"layouts/zen_backdrop"
    end

    private

    def generate_referral_slug(original_slug)
      referral = nil
      secret = nil
      secret = ENV['REFERRAL_SECRET'] if ENV.has_key? 'REFERRAL_SECRET'
      token = request.cookies["ref"]
      uri = Addressable::URI.new

      if token && secret
        begin
          verifier = Fernet.verifier(secret, token)
          referral = CGI.escape(verifier.data["referrer"])
        rescue Exception => e
          Identity.log(:referral_slug_error => true,
            :exception => e.class.name, :message => e.message)
        end
      end

      uri.query_values = {
        :utm_campaign => request.cookies["utm_campaign"],
        :utm_source   => request.cookies["utm_source"],
        :utm_medium   => request.cookies["utm_medium"],
        :referral     => referral,
      }

      # no tracking code, just return the original slug
      if uri.query_values.all? { |k, v| v.nil? }
        return original_slug
      else
        return "#{original_slug}?#{uri.query}"
      end
    end

    def decode_error(body)
      # error might look like:
      #   1. { "id":..., "message":... } (V3)
      #   2. { "error":... } (V2)
      #   3. [["password","is too short (minimum is 6 characters)"]] (V-Insane)
      #   4. "User not found." (V2 404)
      begin
        json = MultiJson.decode(body)
        !json.is_a?(Array) ?
          json["error"] || json["message"] :
          json.map { |e| e.join(" ") }.join("; ")
      rescue MultiJson::DecodeError => e
        # V2 logs some special cases, like 404s, as plain text
        log :decode_error, body: body
        body
      end
    end
  end
end
