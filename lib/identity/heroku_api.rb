require "base64"

module Identity
  class HerokuAPI < Excon::Connection
    def initialize(options={})
      headers = {
        "Accept" => "application/vnd.heroku+json; version=3"
      }
      if options[:user] || options[:pass]
        authorization = Base64.urlsafe_encode64(
          "#{options[:user] || ''}:#{options[:pass] || ''}")
        headers["Authorization"] = "Basic #{authorization}"
      end
      super(Config.heroku_api_url, headers: headers)
    end
  end
end
