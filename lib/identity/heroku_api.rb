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

    def convert_errors
      yield
    rescue Excon::Errors::UnprocessableEntity => e
      err = MultiJson.decode(e.response.body)
      case err['id']
      when 'password_expired'
        raise Identity::Errors::PasswordExpired
      when 'suspended'
        raise Identity::Errors::SuspendedAccount.new(err["message"])
      else
        raise e
      end
    end
  end
end
