module Identity
  class Account < Sinatra::Base
    include SessionHelpers
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
    end

    namespace "/account" do
      # The omniauth strategy makes a call to /account after a successful
      # authentication, so proxy this through to core. Authentication occurs
      # via a header with a bearer token.
      get do
        return 401 if !request.env["HTTP_AUTHORIZATION"]
        api = HerokuAPI.new(user: nil, request_id: request_id,
          authorization: request.env["HTTP_AUTHORIZATION"])
        res = api.get(path: "/account", expects: 200)
        content_type(:json)
        res.body
      end

      post do
        api = HerokuAPI.new(request_id: request_id)
        res = api.post(path: "/signup", expects: [200, 422],
          query: { email: params[:email], slug: self.signup_source })
        json = MultiJson.decode(res.body)
        slim :"account/finish_new"
      end

      get "/accept/:id/:hash" do |id, hash|
        api = HerokuAPI.new(request_id: request_id)
        res = api.get(path: "/signup/accept2/#{id}/#{hash}",
          expects: [200, 422])
        json = MultiJson.decode(res.body)

        if res.status == 422
          flash.now[:error] = json["message"]
          slim :login
        else
          @user = json
          slim :"account/accept2"
        end
      end

      get "/new" do
        self.signup_source = params[:slug]
        slim :"account/new"
      end

      get "/password/reset" do
        slim :"account/password/reset"
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

        slim :"account/password/reset"
      end

      get "/password/reset/:hash" do |hash|
        api = HerokuAPI.new(request_id: request_id)
        res = api.get(path: "/auth/finish_reset_password/#{hash}",
          expects: [200, 404])

        if res.status == 404
          slim :"account/password/not_found"
        else
          @user = MultiJson.decode(res.body)
          slim :"account/password/finish_reset"
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
          slim :"account/password/not_found"
        elsif res.status == 422
          flash.now[:error] = json["errors"]
          slim :"account/password/finish_reset"
        else
          flash[:success] = "Your password has been changed."
          redirect to("/login")
        end
      end
    end

    private

    def request_id
      request.env["REQUEST_ID"]
    end
  end
end
