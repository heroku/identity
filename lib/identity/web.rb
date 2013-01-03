module Identity
  class Web < Sinatra::Base
    register Sinatra::Namespace

    configure do
      set :sessions, true
      set :views, "#{Config.root}/views"
    end

    namespace "/sessions" do
      get do
        slim :"sessions/new"
      end

      post do
        user, pass = params[:email], params[:password]
        @api = HerokuAPI.new(user: user, pass: pass)
      end
    end
  end
end
