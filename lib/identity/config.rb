module Identity
  module Config
    extend self

    def dashboard_url
      ENV["DASHBOARD_URL"] || raise("missing=DASHBOARD_URL")
    end

    def heroku_api_url
      ENV["HEROKU_API_URL"] || raise("missing=HEROKU_API_URL")
    end

    def heroku_oauth_id
      ENV["HEROKU_OAUTH_ID"] || raise("missing=HEROKU_OAUTH_ID")
    end

    def heroku_oauth_secret
      ENV["HEROKU_OAUTH_SECRET"] || raise("missing=HEROKU_OAUTH_SECRET")
    end

    def production?
      ENV["RACK_ENV"] == "production"
    end

    def root
      @root ||= File.expand_path("../../../", __FILE__)
    end

    def secure_key
      ENV["SECURE_KEY"] || raise("missing=SECURE_KEY")
    end
  end
end
