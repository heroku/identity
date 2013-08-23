require "base64"

module Identity
  class HerokuAPI < Excon::Connection
    def initialize(options={})
      headers     = options[:headers] || {}
      ip          = options[:ip] || raise("missing=ip")
      request_ids = options[:request_ids] || []
      version     = options[:version] || raise("missing=version")

      headers = {
        "Accept"          => "application/vnd.heroku+json; version=#{version}",
        # explicitly specify this or bodies will be interpreted as JSON
        "Request-ID"      => request_ids,
        "X-Forwarded-For" => ip,
      }.merge!(headers)

      if version == 3
        headers.merge!("Content-Type" => "application/json")
      else
        headers.merge!("Content-Type" => "application/x-www-form-urlencoded")
      end

      if options[:user] || options[:pass]
        authorization = ["#{options[:user] || ''}:#{options[:pass] || ''}"].
          pack('m').delete("\r\n")
        headers["Authorization"] = "Basic #{authorization}"
      elsif options[:authorization]
        headers["Authorization"] = options[:authorization]
      end

      super(Config.heroku_api_url, headers: headers, instrumentor:
        ExconInstrumentor.new(request_id: request_ids))
    end
  end
end
