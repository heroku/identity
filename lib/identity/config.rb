module Identity
  module Config
    extend self

    def airbrake_api_key
      ENV["AIRBRAKE_API_KEY"]
    end

    def cookie_encryption_key
      ENV["COOKIE_ENCRYPTION_KEY"] || raise("missing=COOKIE_ENCRYPTION_KEY")
    end

    # domain that a cookie-based session nonce will be made available to
    def heroku_cookie_domain
      ENV["HEROKU_COOKIE_DOMAIN"]
    end

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

    def mixpanel_token
      ENV["MIXPANEL_TOKEN"]
    end

    def production?
      ENV["RACK_ENV"] == "production"
    end

    def release
      @release ||= ENV["RELEASE"] || "1"
    end

    def root
      @root ||= File.expand_path("../../../", __FILE__)
    end

    # useful for staging environments with less-than-valid certs
    #   e.g. api.staging.herokudev.com
    def ssl_verify_peer?
      ENV["SSL_VERIFY_PEER"] != "false"
    end
  end
end
