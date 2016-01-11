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

      # for new session, we always encode with the latest `fernet`
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
      Identity.log(:exception,
                   class: e.class.name,
                   message: e.message,
                   fernet: true,
                   backtrace: e.backtrace.inspect)
      {}
    end

    private

    def decode_with_key(cipher, key)
      # There can be URL encoded characters
      # from the cookies
      cipher = CGI::unescape(cipher)
      decode_with_latest_fernet(cipher, key) ||
        decode_with_legacy_fernet(cipher, key)
    end

    def decode_with_legacy_fernet(cipher, key)
      legacy_verifier = LegacyFernet.verifier(key, cipher)
      legacy_verifier.enforce_ttl = false
      legacy_verifier.verify_token(cipher)
      if legacy_verifier.valid?
        Identity.log(:legacy,
                     message: "Decoding with legacy fernet",
                     legacy_fernet: true)
        return Marshal.load(
          Base64.urlsafe_decode64(legacy_verifier.data["session"])
        )
      end
    rescue
      # mute any exception and let latest fernet to try again
      # see `decode_with_latest_fernet`
    end

    def decode_with_latest_fernet(cipher, key)
      verifier = Fernet.verifier(key, cipher)
      verifier.enforce_ttl = false
      return nil unless verifier.valid?

      Marshal.load(Base64.urlsafe_decode64(verifier.message))
    end
  end
end
