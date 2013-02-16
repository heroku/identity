require "base64"
require "rack/session/cookie"

class PrintCoder
  def encode(raw)
  p "ENCODING = #{raw}"
    raw
  end

  def decode(token)
  p "DECODING = #{raw}"
    raw
  end
end

class FernetCookieCoder
  attr_accessor :key

  def initialize(key)
    @key = key
  end

  def encode(raw)
    data = Base64.urlsafe_encode64(Marshal.dump(raw))
    Fernet.generate(key) do |generator|
      # use Marshal instead of JSON to avoid trouble with string/symbol
      # conversions
      generator.data = { "session" => data }
    end
  end

  def decode(token)
    verifier = Fernet.verifier(key, token)
    verifier.enforce_ttl = false
    verifier.verify_token(token)
    raise "signature invalid" unless verifier.valid?
    Marshal.load(Base64.urlsafe_decode64(verifier.data["session"]))
  # fernet throws random exceptions :{ eat it for now
  rescue Exception => e
    Slides.log(:exception, class: e.class.name, message: e.message)
    {}
  end
end
