require "addressable/uri"
require 'cgi'

module Identity
  class Account < Sinatra::Base
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
            ip: request.ip,
          # not necessarily V3, respond with whatever the client asks for
          headers: {
            "Accept" => request.env["HTTP_ACCEPT"] || "application/json"
          })
        begin
          res = api.get(path: "/account", expects: 200)
          content_type(:json)
          res.body
        rescue Excon::Errors::Unauthorized
          return 401
        end
      end

      post do
        begin
          api = HerokuAPI.new(ip: request.ip, request_ids: request_ids,
            version: 2)
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

      get "/accept/:id/:token" do |id, token|
        begin
          api = HerokuAPI.new(ip: request.ip, request_ids: request_ids,
            version: 2)
          res = api.get(path: "/invitation2/show", expects: 200,
            body: URI.encode_www_form({
              "id"    => id,
              "token" => token,
            }))
          @user = MultiJson.decode(res.body)
          @id = id
          @token = token

          # Try an "experimental" signup flow if the user matched a configured
          # signup slug. Currently in use by Devcenter to improve the user
          # on-boarding experience.
          if experimental_signup_slug?(@user["signup_source_slug"])
            redirect to("#{Config.experimental_signup_url}#{request.path_info}")
          else
            slim :"account/accept", layout: :"layouts/classic"
          end
        # Core should return a 404, but returns a 422
        rescue Excon::Errors::NotFound, Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          slim :login, layout: :"layouts/zen_backdrop"
        end
      end

      # This endpoint is unreachable except if a user manually hits it by
      # manipulating their browser during the signup process.
      get "/accept/ok" do
        redirect to(Config.dashboard_url)
      end

      # This endpoint is NOT protected against CSRF, because Dev Center wants to
      # reach it from a different app to test a different onboarding experience.
      post "/accept/ok" do
        begin
          api = HerokuAPI.new(ip: request.ip, request_ids: request_ids,
            version: 2)
          res = api.post(path: "/invitation2/save", expects: 200,
            body: URI.encode_www_form({
              "id"                          => params[:id],
              "token"                       => params[:token],
              "user[password]"              => params[:password],
              "user[password_confirmation]" => params[:password_confirmation],
              "user[receive_newsletter]"    => params[:receive_newsletter],
            }))
          json = MultiJson.decode(res.body)

          # log the user in right away
          perform_oauth_dance(json["email"], params[:password], nil)

          @redirect_uri = if @cookie.authorize_params
            # if we know that we're in the middle of an authorization attempt,
            # continue it
            authorize(@cookie.authorize_params)
            # users who signed up from a particular source may have a specialized
            # redirect location; otherwise go to Dashboard
          elsif json["signup_source"]
            json["signup_source"]["redirect_uri"]
          elsif experimental_signup_slug?(json["signup_source_slug"])
            "#{Config.experimental_signup_url}#{request.path_info}"
          elsif slug = json["signup_source_slug"]
            "#{Config.dashboard_url}/signup/finished?#{slug}"
          else
            "#{Config.dashboard_url}/signup/finished"
          end
          slim :"account/signup_interstitial", layout: :"layouts/zen_backdrop"
        # given client_id wasn't found (API throws a 400 status)
        rescue Excon::Errors::BadRequest
          flash[:error] = "Unknown OAuth client."
          redirect to("/login")
        # we couldn't track the user's session meaning that it's likely been
        # destroyed or expired, redirect to login
        rescue Excon::Errors::NotFound
          redirect to("/login")
        # refresh token dance was unsuccessful
        rescue Excon::Errors::Unauthorized
          redirect to("/login")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          @scope  = @cookie && @cookie.authorize_params["scope"] || nil
          slim :"clients/authorize", layout: :"layouts/zen_backdrop"
        # some problem occurred with the signup
        rescue Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/account/accept/#{params[:id]}/#{params[:token]}")
        end
      end

      get "/email/confirm/:token" do |token|
        begin
          # confirming an e-mail change requires authentication
          raise Identity::Errors::NoSession if !@cookie.access_token
          api = HerokuAPI.new(user: nil, pass: @cookie.access_token,
            ip: request.ip, request_ids: request_ids, version: 2)
          # currently returns a 302, but will return a 200
          api.post(path: "/confirm_change_email/#{token}", expects: [200, 302])
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
          api = HerokuAPI.new(ip: request.ip, request_ids: request_ids,
            version: 2)
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

      get "/password/reset/:token" do |token|
        begin
          api = HerokuAPI.new(ip: request.ip, request_ids: request_ids,
            version: 2)
          res = api.get(path: "/auth/finish_reset_password/#{token}",
            expects: 200)

          @user = MultiJson.decode(res.body)
          slim :"account/password/finish_reset", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::NotFound => e
          slim :"account/password/not_found", layout: :"layouts/zen_backdrop"
        end
      end

      post "/password/reset/:token" do |token|
        begin
          api = HerokuAPI.new(ip: request.ip, request_ids: request_ids,
            version: 2)
          res = api.post(path: "/auth/finish_reset_password/#{token}",
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
          redirect to("/account/password/reset/#{token}")
        end
      end
    end

    get "/signup" do
      @cookie.signup_source = params[:slug]
      slim :signup, layout: :"layouts/zen_backdrop"
    end

    get "/signup/:slug" do |slug|
      # Try an "experimental" signup flow if the user matched a configured
      # signup slug. Currently in use by Devcenter to improve the user
      # on-boarding experience.
      if experimental_signup_slug?(slug)
        signup_url = "#{Config.experimental_signup_url}#{request.path}"
        signup_url += "?#{request.query_string}" if params.any?
        redirect to(signup_url)
      else
        @cookie.signup_source = slug
        slim :signup, layout: :"layouts/zen_backdrop"
      end
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

    def experimental_signup_slug?(slug)
      return false unless slug
      # the split here cleans out the campaign stuff added in
      # #generate_referral_slug
      clean_slug = slug.split('?').first
      Config.experimental_signup_slugs.include?(clean_slug)
    end
  end
end
