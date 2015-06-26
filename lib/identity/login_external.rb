# This defines an endpoint for external services such as Fido (Federated
# Identity) and signup.heroku.com so that they can use their own method for
# authentication and set cookies in identity.
# The endpoint is protected by a shared secret.
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
      Config.login_external_secret
    end
  end
end
