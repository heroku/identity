# To test a new design layout called `foo`:
# - add a view in `views/layouts/foo.slim`
# - replicate the design links adding `?layout=foo`

module Identity
  class Design < Sinatra::Base
    register Sinatra::Namespace

    configure do
      set :views, "#{Config.root}/views"
    end

    before do
      flash[:error] = nil
      @layout = params[:layout] ? :"layouts/#{params[:layout]}" : :"layouts/purple"
    end

    namespace "/design" do
      get "/login" do
        if params[:client]
          flash.now[:link_account] = true
          @oauth_client = { "name" => params[:client] }
        end
        slim :"login", layout: @layout
      end

      get "/login-flash" do
        flash[:error] = "There was a problem with your login."
        slim :"login", layout: @layout
      end

      get "/two-factor" do
        @sms_number = '+1 *** *** 1234'
        slim :"two-factor", layout: @layout
      end

      get "/two-factor/recovery" do
        @sms_number = '+1 *** *** 1234'
        slim :"account/two-factor/recovery", layout: @layout
      end

      get "/two-factor/recovery/sms" do
        @sms_number = '+1 *** *** 1234'
        slim :"account/two-factor/recovery_sms", layout: @layout
      end

      get "/errors/:error" do # 404, 500, 503
        slim :"errors/#{params['error']}", layout: @layout
      end

      get "/authorize" do
        @client = { "name" => "An example app"}
        slim :"clients/authorize", layout: @layout
      end

      namespace "/password" do
        get "/finish-reset" do
          @user = { "email" => "user@example.com"}
          slim :"account/password/finish_reset", layout: @layout
        end

        get "/not-found" do
          slim :"account/password/not_found", layout: @layout
        end

        get "/reset" do
          slim :"account/password/reset", layout: @layout
        end
      end

      get "*" do
        slim :"design/index"
      end
    end

    def client_deny_url
      "https://id.heroku.com/#deny"
    end
  end
end
