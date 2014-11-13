module Identity
  class Design < Sinatra::Base
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
    end

    before do
      flash[:error] = nil
      @layout = :"layouts/purple" if params[:purple]
    end

    namespace "/design" do
      get "/login" do
        slim :"login", layout: @layout || :"layouts/zen_backdrop"
      end

      get "/login-flash" do
        flash[:error] = "There was a problem with your login."
        slim :"login", layout: @layout || :"layouts/zen_backdrop"
      end

      get "/two-factor" do
        slim :"two-factor", layout: @layout || :"layouts/zen_backdrop"
      end

      get "/errors/:error" do # 404, 500, 503
        slim :"errors/#{params['error']}", layout: @layout || :"layouts/classic"
      end

      get "/authorize" do
        @client = { "name" => "An example app"}
        slim :"clients/authorize", layout: @layout || :"layouts/zen_backdrop"
      end

      namespace "/password" do
        get "/finish-reset" do
          @user = { "email" => "user@example.com"}
          slim :"account/password/finish_reset", layout: @layout || :"layouts/zen_backdrop"
        end

        get "/not-found" do
          slim :"account/password/not_found", layout: @layout || :"layouts/zen_backdrop"
        end

        get "/reset" do
          slim :"account/password/reset", layout: @layout || :"layouts/zen_backdrop"
        end
      end

      get "*" do
        slim :"design/index"
      end
    end
  end
end
