module Identity::Errors
  class NoSession < StandardError
  end

  class PasswordExpired < StandardError
    attr_accessor :message

    def initialize(msg)
      @message = msg
    end
  end

  class UnauthorizedClient < StandardError
    attr_accessor :client

    def initialize(client)
      @client = client
    end
  end

  class SuspendedAccount < StandardError
    attr_accessor :message

    def initialize(msg)
      @message = msg
    end
  end
end
