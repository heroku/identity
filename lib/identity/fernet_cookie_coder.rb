require "base64"
require "rack/session/cookie"

module Identity
  class FernetCookieCoder
    def initialize(*keys)
      @keys = keys.compact
    end

    def encode(raw)
      # use Marshal instead of JSON to avoid trouble with string/symbol
      # conversions
      data = Base64.urlsafe_encode64(Marshal.dump(raw))
      Fernet.generate(@keys.first, data)
    end

    def decode(cipher)
      return {} if cipher == nil
      plain = nil
      @keys.each do |key|
        begin
          plain = decode_with_key(cipher, key)
        rescue OpenSSL::Cipher::CipherError
        end

        break if plain
      end
      raise "no valid encryption key for cipher" if !plain
      plain
    # fernet throws random exceptions :{ eat it for now
    rescue Exception => e
      Identity.log(:exception, class: e.class.name, message: e.message,
        fernet: true, backtrace: e.backtrace.inspect)
      {}
    end

    private

    def decode_with_key(cipher, key)
      verifier = Fernet.verifier(key, cipher)
      verifier.enforce_ttl = false
      return nil unless verifier.valid?

      Marshal.load(Base64.urlsafe_decode64(verifier.message))
    end
  end
end
