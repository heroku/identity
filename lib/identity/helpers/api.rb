module Identity::Helpers
  module API
    def decode_error(body)
      # error might look like:
      #   1. { "id":..., "message":... } (V3)
      #   2. { "error":... } (V2)
      #   3. [["password","is too short (minimum is 6 characters)"]] (V-Insane)
      #   4. {"password":["is too short (minimum is 15 characters for Herokai)"]}
      #   5. "User not found." (V2 404)

      begin
        json = MultiJson.decode(body)

        unless json.is_a?(Array)
          if json.has_key?("error") ||
              json.has_key?("message") ||
              json.has_key?("password")
            json.map { |e| e.join(" ") }.join("; ")
          end
        end
      rescue MultiJson::DecodeError => e
        # V2 logs some special cases, like 404s, as plain text
        log :decode_error, body: body
        body
      end
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
