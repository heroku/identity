module Identity
  module Config
    extend self

    def heroku_api_url
      ENV["HEROKU_API_URL"] || raise("missing=HEROKU_API_URL")
    end

    def production?
      ENV["RACK_ENV"] == "production"
    end

    def root
      @root ||= File.expand_path("../../../", __FILE__)
    end
  end
end
