require_relative "test_helper"

describe Identity::FernetCookieCoder do
  secret = "Pw/Xv58CsV8FVUQldtbHRZBoGqv8pJ1u55JdlhsRp9A="
  another_secret = "r1auRylYrR9WM3dhRkfXRwQ5nxcNGR2lBkCLgXl94gU="

  it "encrypts a cookie, then decrypts a cookie" do
    data = { access_token: "5ff6ad27-1946-4abb-9f25-ad4e37014ea7" }
    coder = Identity::FernetCookieCoder.new(secret)
    cipher = coder.encode(data)
    assert_equal data, coder.decode(cipher)
  end

  it "encrypts with the first given key" do
    data = { access_token: "5ff6ad27-1946-4abb-9f25-ad4e37014ea7" }
    coder = Identity::FernetCookieCoder.new(secret)
    coder.encode(data)
    coder = Identity::FernetCookieCoder.new(another_secret, secret)
    refute_equal data, coder.encode(data)
  end

  it "enables graceful encryption key rotation" do
    data = { access_token: "5ff6ad27-1946-4abb-9f25-ad4e37014ea7" }
    coder = Identity::FernetCookieCoder.new(secret)
    cipher = coder.encode(data)
    coder = Identity::FernetCookieCoder.new(another_secret, secret)
    assert_equal data, coder.decode(cipher)
  end

  it "decrypts with legacy fernet" do
    data = { access_token: "5ff6ad27-1946-4abb-9f25-ad4e37014ea7" }
    legacy_cipher = generate_legacy_cipher(secret, data)
    coder = Identity::FernetCookieCoder.new(secret)
    assert_equal data, coder.decode(legacy_cipher)
  end

  def generate_legacy_cipher(key, raw)
    data = Base64.urlsafe_encode64(Marshal.dump(raw))
    LegacyFernet.generate(key) do |generator|
      generator.data = { "session" => data }
    end
  end
end
