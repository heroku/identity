module Identity::Helpers
  module API
    def decode_error(body)
      json = MultiJson.decode(body)

      if json.is_a?(Hash)
        # use the message field, otherwise munge the errors together
        json["message"] || json.map { |e| e.join(" ") }.join("; ")
      end
    rescue MultiJson::DecodeError
      # V2 logs some special cases, like 404s, as plain text
      log :decode_error, body: body
      body
    end

    def fetch_sms_number
      return unless @cookie.email && @cookie.password

      options = {
        ip: request.ip,
        request_ids: request_ids,
        user: @cookie.email,
        pass: @cookie.password,
        version: "3",
      }

      api = Identity::HerokuAPI.new(options)
      res = api.get(path: "/users/~/sms-number",
          expects: 200)
      MultiJson.decode(res.body)["sms_number"]
    rescue
      nil
    end
  end
end
