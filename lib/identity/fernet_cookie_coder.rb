require "rack/session/cookie"

class FernetCookieCoder
  attr_accessor :key

  def initialize(key)
    @key = key
  end

  def encode(raw)
    Fernet.generate(key) do |generator|
      generator.data = { "session" => raw }
    end
  end

  def decode(token)
    verifier = Fernet.verifier(key, token)
    verifier.enforce_ttl = false
    return unless verifier.valid?
    verifier.data["session"]
  # fernet throws random exceptions :{ eat it for now
  rescue Exception => e
  end
end
