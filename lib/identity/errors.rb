module Identity::Errors
  class UnauthorizedClient < StandardError
    attr_accessor :client

    def initialize(client)
      @client = client
    end
  end
end
