module Identity
  class Account < Sinatra::Base
    include SessionHelpers
    register Identity::ErrorHandling
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
    end

    namespace "/account" do
      # The omniauth strategy used to make a call to /account after a
      # successful authentication, so proxy this through to core.
      # Authentication occurs via a header with a bearer token.
      #
      # Remove this as soon as we get Devcenter and Dashboard upgraded.
      get do
        return 401 if !request.env["HTTP_AUTHORIZATION"]
        api = HerokuAPI.new(user: nil, request_id: request_id,
          authorization: request.env["HTTP_AUTHORIZATION"],
          # not necessarily V3, respond with whatever the client asks for
          headers: { request.env["HTTP_ACCEPT"] })
        res = api.get(path: "/account", expects: 200)
        content_type(:json)
        res.body
      end

      post do
        api = HerokuAPI.new(request_id: request_id)
        res = api.post(path: "/signup", expects: [200, 422],
          query: { email: params[:email], slug: self.signup_source })
        json = MultiJson.decode(res.body)
        slim :"account/finish_new", layout: :"layouts/zen_backdrop"
      end

      get "/accept/:id/:hash" do |id, hash|
        api = HerokuAPI.new(request_id: request_id)
        res = api.get(path: "/signup/accept2/#{id}/#{hash}",
          expects: [200, 422])
        json = MultiJson.decode(res.body)

        if res.status == 422
          flash.now[:error] = json["message"]
          slim :login, layout: :"layouts/zen_backdrop"
        else
          @user = json
          slim :"account/accept", layout: :"layouts/classic"
        end
      end

      post "/accept/:id/:hash" do |id, hash|
        api = HerokuAPI.new(request_id: request_id)
        res = api.post(path: "/invitation2/save", expects: [200, 422],
          query: {
            "id"                          => id,
            "token"                       => hash,
            "user[password]"              => params[:password],
            "user[password_confirmation]" => params[:password_confirmation],
            "user[receive_newsletter]"    => params[:receive_newsletter],
          })
        json = MultiJson.decode(res.body)

        if res.status == 422
          flash.now[:error] = json["message"]
          slim :"account/accept", layout: :"layouts/classic"
        else
          # users who signed up from a particular source may have a specialized
          # redirect location; otherwise go to Dashboard
          if json["signup_source"]
            redirect to(json["signup_source"]["redirect_uri"])
          else
            redirect to("#{Config.dashboard_url}/signup/finished")
          end
        end
      end

      get "/password/reset" do
        slim :"account/password/reset", layout: :"layouts/zen_backdrop"
      end

      post "/password/reset" do
        api = HerokuAPI.new(request_id: request_id)
        # @todo: use bare email instead of reset[email] when ready
        res = api.post(path: "/auth/reset_password", expects: [200, 422],
          query: { "reset[email]" => params[:email] })
        json = MultiJson.decode(res.body)

        if res.status == 422
          flash.now[:error] = json["message"]
        else
          flash.now[:notice] = json["message"]
        end

        slim :"account/password/reset", layout: :"layouts/zen_backdrop"
      end

      get "/password/reset/:hash" do |hash|
        api = HerokuAPI.new(request_id: request_id)
        res = api.get(path: "/auth/finish_reset_password/#{hash}",
          expects: [200, 404])

        if res.status == 404
          slim :"account/password/not_found", layout: :"layouts/zen_backdrop"
        else
          @user = MultiJson.decode(res.body)
          slim :"account/password/finish_reset", layout: :"layouts/zen_backdrop"
        end
      end

      post "/password/reset/:hash" do |hash|
        api = HerokuAPI.new(request_id: request_id)
        res = api.post(path: "/auth/finish_reset_password/#{hash}",
          expects: [200, 404, 422], query: {
            "user_to_reset[password]"              => params[:password],
            "user_to_reset[password_confirmation]" =>
              params[:password_confirmation],
          })

        if res.status == 404
          slim :"account/password/not_found", layout: :"layouts/zen_backdrop"
        elsif res.status == 422
          flash.now[:error] = json["errors"]
          slim :"account/password/finish_reset", layout: :"layouts/zen_backdrop"
        else
          flash[:success] = "Your password has been changed."
          redirect to("/login")
        end
      end
    end

    get "/signup" do
      self.signup_source = params[:slug]
      slim :signup, layout: :"layouts/zen_backdrop"
    end

    private

    def request_id
      request.env["REQUEST_ID"]
    end
  end
end
