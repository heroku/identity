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
        api = HerokuAPI.new(user: nil, request_ids: request_ids,
          authorization: request.env["HTTP_AUTHORIZATION"],
          # not necessarily V3, respond with whatever the client asks for
          headers: { "Accept" => request.env["HTTP_ACCEPT"] })
        res = api.get(path: "/account", expects: 200)
        content_type(:json)
        res.body
      end

      post do
        begin
          api = HerokuAPI.new(request_ids: request_ids)
          res = api.post(path: "/signup", expects: [200, 422],
            query: { email: params[:email], slug: @cookie.signup_source })
          json = MultiJson.decode(res.body)
          slim :"account/finish_new", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::UnprocessableEntity => e
          # during transition, handle either V3 or V2 error responses
          json = MultiJson.decode(e.response.body)
          flash[:error] = e["error"] || e["message"]
          redirect to("/signup")
        end
      end

      get "/accept/:id/:hash" do |id, hash|
        begin
          api = HerokuAPI.new(request_ids: request_ids)
          res = api.get(path: "/invitation2/show", expects: 200,
            query: {
              "id"    => id,
              "token" => hash,
            })
          @user = MultiJson.decode(res.body)
          slim :"account/accept", layout: :"layouts/classic"
        # Core should return a 404, but returns a 422
        rescue Excon::Errors::NotFound, Excon::Errors::UnprocessableEntity => e
          json = MultiJson.decode(e.response.body)
          flash.now[:error] = json["message"]
          slim :login, layout: :"layouts/zen_backdrop"
        end
      end

      post "/accept/:id/:hash" do |id, hash|
        begin
          api = HerokuAPI.new(request_ids: request_ids)
          res = api.post(path: "/invitation2/save", expects: 200,
            query: {
              "id"                          => id,
              "token"                       => hash,
              "user[password]"              => params[:password],
              "user[password_confirmation]" => params[:password_confirmation],
              "user[receive_newsletter]"    => params[:receive_newsletter],
            })
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
          else
            redirect to("#{Config.dashboard_url}/signup/finished")
          end
        # given client_id wasn't found
        rescue Excon::Errors::NotFound
          flash[:error] = "Unknown OAuth client."
          redirect to("/login")
        # refresh token dance was unsuccessful
        rescue Excon::Errors::Unauthorized
          redirect to("/login")
        # client not yet authorized; show the user a confirmation dialog
        rescue Identity::Errors::UnauthorizedClient => e
          @client = e.client
          @cookie.authorize_params = authorize_params
          slim :"clients/authorize", layout: :"layouts/zen_backdrop"
        # some problem occurred with the signup
        rescue Excon::Errors::UnprocessableEntity => e
          json = MultiJson.decode(e.response.body)
          flash[:error] = json.map { |e| e.join(" ") }.join("; ")
          redirect to("/account/accept/#{id}/#{hash}")
        end
      end

      get "/email/confirm/:hash" do |hash|
        begin
          # confirming an e-mail change requires authentication
          raise Identity::Errors::NoSession if !@cookie.access_token
          api = HerokuAPI.new(user: nil, pass: @cookie.access_token,
            request_ids: request_ids)
          # currently returns a 302, but will return a 200
          api.post(path: "/confirm_change_email/#{hash}", expects: [200, 302])
          redirect to(Config.dashboard_url)
        rescue Excon::Errors::NotFound, Excon::Errors::UnprocessableEntity => e
          slim :"account/email/not_found", layout: :"layouts/zen_backdrop"
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
          api = HerokuAPI.new(request_ids: request_ids)
          res = api.post(path: "/auth/reset_password", expects: 200,
            query: { email: params[:email] })

          json = MultiJson.decode(res.body)
          flash.now[:notice] = json["message"]
          slim :"account/password/reset", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::UnprocessableEntity => e
          json = MultiJson.decode(e.response.body)
          flash[:error] = json.map { |e| e.join(" ") }.join("; ")
          redirect to("/account/password/reset")
        end
      end

      get "/password/reset/:hash" do |hash|
        begin
          api = HerokuAPI.new(request_ids: request_ids)
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
          api = HerokuAPI.new(request_ids: request_ids)
          res = api.post(path: "/auth/finish_reset_password/#{hash}",
            expects: 200, query: {
              :password              => params[:password],
              :password_confirmation => params[:password_confirmation],
            })

          flash[:success] = "Your password has been changed."
          redirect to("/login")
        rescue Excon::Errors::NotFound => e
          slim :"account/password/not_found", layout: :"layouts/zen_backdrop"
        rescue Excon::Errors::UnprocessableEntity => e
          # error looks like:
          #   [["password","is too short (minimum is 6 characters)"]]
          json = MultiJson.decode(e.response.body)
          flash[:error] = json.map { |e| e.join(" ") }.join("; ")
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
  end
end
