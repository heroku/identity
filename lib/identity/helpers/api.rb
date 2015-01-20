module Identity::Helpers
  module API
    def decode_error(body)
      # error might look like:
      #   1. { "id":..., "message":... } (V3)
      #   2. { "error":... } (V2)
      #   3. [["password","is too short (minimum is 6 characters)"]] (V-Insane)
      #   4. "User not found." (V2 404)
      begin
        json = MultiJson.decode(body)
        !json.is_a?(Array) ?
          json["error"] || json["message"] :
          json.map { |e| e.join(" ") }.join("; ")
      rescue MultiJson::DecodeError => e
        # V2 logs some special cases, like 404s, as plain text
        log :decode_error, body: body
        body
      end
    end

    def perform_sms_number_lookup
      return unless @cookie.email && @cookie.password

      options = {
        ip: request.ip,
        request_ids: request_ids,
        user: @cookie.email,
        pass: @cookie.password,
        version: "3.sms-number",
      }

      api = Identity::HerokuAPI.new(options)
      res = api.get(path: "/account/sms-number",
          expects: 200)
      MultiJson.decode(res.body)["sms_number"]
    rescue
      nil
    end
  end
end
