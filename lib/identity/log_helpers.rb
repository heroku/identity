module Identity
  module LogHelpers
    def log(action, data={}, &block)
      data.merge! id: request_id
      Identity.log(action, data.merge(data), &block)
    end

    def request_id
      request.env["REQUEST_ID"]
    end
  end
end
