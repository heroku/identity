module Identity::Errors
  class LoginRequired < StandardError; end
  class SSORequired < StandardError; end

  class PasswordExpired < StandardError
    attr_accessor :message

    def initialize(_)
      # Override this message so that the user doesn't see a URL that they're
      # supposed to visit. Instead, just take them directly to the write place.
      @message = <<-eos.strip
        Your password has expired. Please reset it.
      eos
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
