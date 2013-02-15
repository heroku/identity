module Identity
  class Default < Sinatra::Base
    register Identity::ErrorHandling

    configure do
      set :views, "#{Config.root}/views"
    end

    get "/" do
      if @cookie.access_token
        redirect to(Config.dashboard_url)
      else
        redirect to("/login")
      end
    end

    not_found do
      slim :"errors/404", layout: :"layouts/classic"
    end
  end
end
