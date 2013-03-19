require "base64"

module Identity
  class HerokuAPI < Excon::Connection
    def initialize(options={})
      options[:headers] ||= {}
      options[:request_ids] ||= []
      headers = {
        #
        # Consumed OAuth APIs are V3, but signup/email change/password reset
        # APIs are not. This is largely because these V3 APIs do not yet exist.
        # Move Identity back to V3 after they're properly implemented.
        #
        #"Accept"     => "application/vnd.heroku+json; version=3",
        "Request-ID" => options[:request_ids].join(", "),
      }.merge!(options[:headers])
      if options[:user] || options[:pass]
        authorization = ["#{options[:user] || ''}:#{options[:pass] || ''}"].
          pack('m').delete("\r\n")
        headers["Authorization"] = "Basic #{authorization}"
      elsif options[:authorization]
        headers["Authorization"] = options[:authorization]
      end
      super(Config.heroku_api_url, headers: headers, instrumentor:
        ExconInstrumentor.new(id: options[:request_ids].join(",")))
    end
  end
end
