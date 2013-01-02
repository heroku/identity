require 'base64'

module Identity
  class HerokuAPI
    def initialize(options={})
      authorization = Base64.encode64("#{options[:user]}:#{options[:pass]}")
      @conn = Excon.new(Config.heroku_api_url,
        headers: { "Authorization" => "Basic #{authorization}" })
    end

    def get
    end
  end
end
