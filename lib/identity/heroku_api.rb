require "base64"

module Identity
  class HerokuAPI < Excon::Connection
    def initialize(options={})
      options[:headers] ||= {}
      options[:request_ids] ||= []
      version = options[:version] || raise("missing=version")
      headers = {
        "Accept"       => "application/vnd.heroku+json; version=#{version}",
        # explicitly specify this or bodies will be interpreted as JSON
        "Content-Type" => "application/x-www-form-urlencoded",
        "Request-ID"   => options[:request_ids],
      }.merge!(options[:headers])
      if options[:user] || options[:pass]
        authorization = ["#{options[:user] || ''}:#{options[:pass] || ''}"].
          pack('m').delete("\r\n")
        headers["Authorization"] = "Basic #{authorization}"
      elsif options[:authorization]
        headers["Authorization"] = options[:authorization]
      end
      super(Config.heroku_api_url, headers: headers, instrumentor:
        ExconInstrumentor.new(id: options[:request_ids]))
    end
  end
end
