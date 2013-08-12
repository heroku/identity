module Identity
  module LogHelpers
    def log(action, data={}, &block)
      data.merge! app: "identity", request_id: request_ids

      # A UUID in a shared cookie allows correlating OAuth logs with other Heroku properties
      data.merge! oauth_dance_id: @oauth_dance_id if @oauth_dance_id

      Slides.log(action, data, &block)
    end

    def request_ids
      request.env["REQUEST_IDS"]
    end
  end
end
