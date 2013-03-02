module Identity
  module LogHelpers
    def log(action, data={}, &block)
      data.merge! app: "identity",
        id: request_ids ? request_ids.join(",") : nil
      data += request_ids.map { |id| [:id, id] } if request_ids
      Slides.log_array(action, data, &block)
    end

    def request_ids
      request.env["REQUEST_IDS"]
    end
  end
end
