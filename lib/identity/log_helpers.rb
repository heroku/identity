module Identity
  module LogHelpers
    def log(action, data={}, &block)
      data.merge! app: "identity", request_id: request_ids
      Slides.log(action, data, &block)
    end

    def request_ids
      request.env["REQUEST_IDS"]
    end
  end
end
