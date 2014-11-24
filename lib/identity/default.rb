module Identity
  class Default < Sinatra::Base
    register ErrorHandling
    register HerokuCookie

    configure do
      set :views, "#{Config.root}/views"
    end

    before do
      @cookie = Cookie.new(env["rack.session"])
    end

    get "/" do
      if @cookie.access_token
        redirect to(Config.dashboard_url)
      else
        redirect to("/login")
      end
    end

    not_found do
      slim :"errors/404", layout: :"layouts/purple"
    end
  end
end
