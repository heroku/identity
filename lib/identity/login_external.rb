module Identity
  class LoginExternal < Default
    register Sinatra::Namespace
    include Helpers::Auth

    namespace "/login/external" do
      before do
        halt 404 unless shared_key
      end

      get do
        token = params[:token]
        auth, _ = JWT.decode(token, shared_key)
        write_authentication_to_cookie auth
        redirect to(Config.dashboard_url)
      end

      error JWT::DecodeError do
        handle_error 401
      end
    end

    private

    def shared_key
      Config.finalize_shared_secret
    end
  end
end
