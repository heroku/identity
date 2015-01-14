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

      if version == 2
        headers.merge!("Content-Type" => "application/x-www-form-urlencoded")
      else
        headers.merge!("Content-Type" => "application/json")
      end

      if options[:user] || options[:pass]
        authorization = ["#{options[:user] || ''}:#{options[:pass] || ''}"].
          pack('m').delete("\r\n")
        headers["Authorization"] = "Basic #{authorization}"
      elsif options[:authorization]
        headers["Authorization"] = options[:authorization]
      end

      uri = URI.parse(Config.heroku_api_url)
      super(
        host: uri.host,
        path: uri.path,
        port: uri.port,
        scheme: uri.scheme,
        headers: headers,
        instrumentor: ExconInstrumentor.new(request_id: request_ids))
    end

    %i(delete get patch post put).each do |verb|
      define_method(verb) do |*args|
        convert_errors do
          super(*args)
        end
      end
    end

    private

    # Maps V3 error identifiers to custom error classes.
    #
    # This is a relatively new concept where before we just had multiple
    # conditionals inside of a single rescue of an Excon status-class error. We
    # should try to aim to increasingly move toward this model for better
    # clarity.
    ERROR_MAP = {
      password_expired:  Identity::Errors::PasswordExpired,
      suspended:         Identity::Errors::SuspendedAccount,
    }

    def convert_errors
      yield
    rescue Excon::Errors::HTTPStatusError => e
      error_id, error_message = begin
        data = MultiJson.decode(e.response.body)
        [data["id"].try(:to_sym), data["message"]]
      rescue MultiJson::ParseError
        [nil, nil]
      end

      if klass = ERROR_MAP[error_id]
        raise klass.new(error_message)
      else
        raise
      end
    end
  end
end
