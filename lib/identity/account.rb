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

      get "/accept/:id/:token" do |id, token|
        redirect_to_signup_app(request.path)
      end

      # This endpoint is unreachable except if a user manually hits it by
      # manipulating their browser during the signup process.
      get "/accept/ok" do
        redirect_to_signup_app(request.path)
      end

      # This endpoint is NOT protected against CSRF, because the signup app needs it
      # to verify and log the user in.
      post "/accept/ok" do
        begin
          api = HerokuAPI.new(
            ip:          request.ip,
            request_ids: request_ids,
            version:     3)
          res = api.patch(
            path:    "/invitations/#{params[:token]}",
            expects: 200,
            body:    MultiJson.encode(
              password:              params[:password],
              password_confirmation: params[:password_confirmation],
              receive_newsletter:    params[:receive_newsletter]
            ))
          json = MultiJson.decode(res.body)

          # log the user in right away
          perform_oauth_dance(json["user"]["email"], params[:password], nil)

          @redirect_uri = if @cookie.authorize_params
            # if we know that we're in the middle of an authorization attempt,
            # continue it
            authorize(@cookie.authorize_params)
            # users who signed up from a particular source may have a specialized
            # redirect location; otherwise go to Dashboard
          else
            redirect_to_signup_app(request.path)
          end
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
          slim :"clients/authorize", layout: :"layouts/purple"
        # some problem occurred with the signup
        rescue Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/account/accept/#{params[:id]}/#{params[:token]}")
        end
      end

      get "/email/confirm/:token" do |token|
        begin
          # confirming an e-mail change requires authentication
          raise Identity::Errors::LoginRequired unless @cookie.access_token
          api = HerokuAPI.new(
            user:        nil,
            pass:        @cookie.access_token,
            ip:          request.ip,
            request_ids: request_ids,
            version:     3)
          api.patch(
            path:    "/users/~",
            expects: 200,
            body:    MultiJson.encode(email_change_token: params[:token]))
          redirect to(Config.dashboard_url)
        # user tried to access the change e-mail request under the wrong
        # account
        rescue Excon::Errors::Forbidden
          flash[:error] = "This link can't be used with your current login."
          redirect to("/login")
        rescue Excon::Errors::NotFound, Excon::Errors::UnprocessableEntity
          slim :"account/email/not_found", layout: :"layouts/purple"
        # it seems that the user's access token is no longer valid, refresh
        rescue Excon::Errors::Unauthorized
          begin
            perform_oauth_refresh_dance
            redirect to(request.path_info)
          # refresh dance unsuccessful
          rescue Excon::Errors::Unauthorized
            redirect to("/logout")
          end
        rescue Identity::Errors::LoginRequired
          @cookie.redirect_url = request.env["PATH_INFO"]
          redirect to("/login")
        end
      end

      get "/password/reset" do
        slim :"account/password/reset", layout: :"layouts/purple"
      end

      post "/password/reset" do
        begin
          api = HerokuAPI.new(
            ip:          request.ip,
            request_ids: request_ids,
            version:     3)
          api.post(
            path:    "/password-resets",
            body:    MultiJson.encode(email: params[:email]),
            expects: 201)

          flash.now[:notice] =
            "Check your inbox for the next steps.\n"\
            "If you don't receive an email, and it's not in your spam folder "\
            "this could mean you signed up with a different address."
          slim :"account/password/reset", layout: :"layouts/purple"
        rescue Excon::Errors::ClientError => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/account/password/reset")
        end
      end

      get "/password/reset/:token" do |token|
        slim :"account/password/finish_reset", layout: :"layouts/purple"
      end

      post "/password/reset/:token" do |token|
        begin
          api = HerokuAPI.new(
            ip:          request.ip,
            request_ids: request_ids,
            version:     3)
          body = MultiJson.encode(
            password:              params[:password],
            password_confirmation: params[:password_confirmation],
          )
          api.post(
            path:    "/password-resets/#{token}/actions/finalize",
            expects: 200,
            body:    body)

          flash[:success] = "Your password has been changed."
          redirect to("/login")
        rescue Excon::Errors::NotFound => e
          status 404
          slim :"account/password/not_found", layout: :"layouts/purple"
        rescue Excon::Errors::ClientError => e
          Identity.log(
            password_reset_error: true,
            error_body:           e.response.body,
            error_code:           e.response.status)

          @user = flash[:user]
          flash[:error] = decode_error(e.response.body)

          redirect to("/account/password/reset/#{token}")
        end
      end

      get "/two-factor/recovery" do
        @sms_number = fetch_sms_number
        slim :"account/two-factor/recovery", layout: :"layouts/purple"
      end

      post "/two-factor/recovery/sms" do
        options = {
          ip: request.ip,
          request_ids: request_ids,
          user: @cookie.email,
          pass: @cookie.password,
          version: "3",
        }

        begin
          api = HerokuAPI.new(options)
          res = api.post(path: "/users/~/sms-number/actions/recover",
            expects: 201)
        rescue Excon::Errors::UnprocessableEntity => e
          flash[:error] = decode_error(e.response.body)
          redirect to("/login/two-factor")
        end

        redirect to("/account/two-factor/recovery/sms")
      end

      get "/two-factor/recovery/sms" do
        @sms_number = fetch_sms_number
        slim :"account/two-factor/recovery_sms", layout: :"layouts/purple"
      end
    end

    get "/signup" do
      redirect_to_signup_app("")
    end

    get "/signup/:slug" do |slug|
      redirect_to_signup_app("/#{params[:slug]}")
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

    # Redirects to the signup app adding a special param
    def redirect_to_signup_app(next_path)
      current_params = CGI.parse(URI.parse(request.fullpath).query.to_s)
      append_params  = { from: 'id' }
      if redirect_url = @cookie.post_signup_url
        append_params["redirect-url"] = redirect_url
      end
      next_params = URI.encode_www_form(current_params.merge(append_params))
      redirect to("#{Config.signup_url}#{next_path}?#{next_params}")
    end
  end
end
