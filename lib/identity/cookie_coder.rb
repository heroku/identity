require "base64"

module Identity
  # CookieCoder encodes and decodes payload before setting it to cookie
  # Different from FernetCookieCoder, it doesn't use Ruby Marshal.
  # The encrypted cookie is meant to consumed by other programming
  # languages other than Ruby.
  class CookieCoder
    def initialize(*keys)
      @keys = keys.compact
    end

    def encode(payload)
      # make sure all keys are strings
      payload = JSON.generate(payload)
      Fernet.generate(@keys.first, payload)
    end

    def decode(cipher)
      return {} if cipher == nil

      # There can be URL encoded characters
      # from the cookies
      cipher = CGI::unescape(cipher)

      plain = nil
      @keys.each do |key|
        begin
          plain = decode_with_key(cipher, key)
        rescue OpenSSL::Cipher::CipherError
        end

        break if plain
      end

      raise "no valid encryption key for cipher" unless plain

      plain
    rescue => e
      Identity.log(:exception,
                   class: e.class.name,
                   message: e.message,
                   fernet: true,
                   backtrace: e.backtrace.inspect
                  )
      {}
    end

    private

    def decode_with_key(cipher, key)
      verifier = Fernet.verifier(key, cipher)
      verifier.enforce_ttl = false

      return nil unless verifier.valid?

      JSON.parse(verifier.message)
    end
  end
end
