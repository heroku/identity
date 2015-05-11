module Identity
  module Config
    extend self

    def cookie_encryption_key
      ENV["COOKIE_ENCRYPTION_KEY"] || raise("missing=COOKIE_ENCRYPTION_KEY")
    end

    def cookie_expire_after
      (ENV["COOKIE_EXPIRE_AFTER"] || 2592000).to_i
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

    def heroku_cookie_domain
      ENV["HEROKU_COOKIE_DOMAIN"] || ".heroku.com"
    end

    def mixpanel_token
      ENV["MIXPANEL_TOKEN"]
    end

    def google_tag_manager_account
      ENV["GOOGLE_TAG_MANAGER_ACCOUNT"]
    end

    def old_cookie_encryption_key
      ENV["OLD_COOKIE_ENCRYPTION_KEY"]
    end

    def rollbar_access_token
      ENV["ROLLBAR_ACCESS_TOKEN"]
    end

    def development?
      ENV["RACK_ENV"] == "development"
    end

    def production?
      ENV["RACK_ENV"] == "production"
    end

    def redirect_all_signups
      !ENV["REDIRECT_ALL_SIGNUPS"].nil?
    end

    def release
      @release ||= ENV["RELEASE"] || "1"
    end

    def root
      @root ||= File.expand_path("../../../", __FILE__)
    end

    def signup_url
      ENV["SIGNUP_URL"] || raise("missing=SIGNUP_URL")
    end

    # useful for staging environments with less-than-valid certs
    #   e.g. api.staging.herokudev.com
    def ssl_verify_peer?
      ENV["SSL_VERIFY_PEER"] != "false"
    end
  end
end
