require "base64"

module Identity
  class HerokuAPI < Excon::Connection
    def initialize(options={})
      authorization = Base64.urlsafe_encode64(
        "#{options[:user] || ''}:#{options[:pass] || ''}")
      super(
        Config.heroku_api_url,
        headers: {
          "Accept"        => "application/json",
          "Authorization" => "Basic #{authorization}",
        })
    end
  end
end
