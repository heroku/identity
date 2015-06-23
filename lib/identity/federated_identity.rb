module Identity
  class FederatedIdentity < Sinatra::Base
    include Helpers::Auth

    register ErrorHandling
    register HerokuCookie
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
    end

    before do
      # short-circuit 404 if federated id is not set up
      raise Sinatra::NotFound unless Config.heroku_fid_url

      @cookie = Cookie.new(env["rack.session"])
    end

    namespace "/federated/:org_name/saml" do
      get "/init" do
        redirect_url = fid_client.get_redirect_url_for(org_name)
        redirect to(redirect_url)
      end

      post "/finalize" do
        saml_response = params[:SAMLResponse]
        auth_data = fid_client.authenticate(org_name, saml_response)
        write_auth_data_to_cookie auth_data
        redirect to(Config.dashboard_url)
      end

      private

      def fid_client
        @fid_client ||= HerokuFidClient.new
      end

      def org_name
        params[:org_name]
      end
    end
  end
end
