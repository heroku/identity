require_relative "test_helper"

describe Identity::FernetCookieCoder do
  it "encrypts a cookie, then decrypts a cookie" do
    data = { access_token: "5ff6ad27-1946-4abb-9f25-ad4e37014ea7" }
    coder = Identity::FernetCookieCoder.new("my-key" * 20)
    cipher = coder.encode(data)
    assert_equal data, coder.decode(cipher)
  end

  it "encrypts with the first given key" do
    data = { access_token: "5ff6ad27-1946-4abb-9f25-ad4e37014ea7" }
    coder = Identity::FernetCookieCoder.new("my-key" * 20)
    cipher = coder.encode(data)
    coder = Identity::FernetCookieCoder.new("my-new-key" * 20, "my-key" * 20)
    refute_equal data, coder.encode(data)
  end

  it "enables graceful encryption key rotation" do
    data = { access_token: "5ff6ad27-1946-4abb-9f25-ad4e37014ea7" }
    coder = Identity::FernetCookieCoder.new("my-key" * 20)
    cipher = coder.encode(data)
    coder = Identity::FernetCookieCoder.new("my-new-key" * 20, "my-key" * 20)
    assert_equal data, coder.decode(cipher)
  end
end
