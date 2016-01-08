require_relative "test_helper"

describe Identity::CookieCoder do
  secret = "Pw/Xv58CsV8FVUQldtbHRZBoGqv8pJ1u55JdlhsRp9A="
  another_secret = "r1auRylYrR9WM3dhRkfXRwQ5nxcNGR2lBkCLgXl94gU="

  it "encryptes a cookie, then descripts a cookie" do
    data = { user: {
      id: "1234",
      email: "example@herou.com",
      full_name: "Full Name"
    }}
    coder = Identity::CookieCoder.new(secret)
    cipher = coder.encode(data)

    assert_equal JSON.parse(JSON.generate(data)), coder.decode(cipher)
  end

  it "encrypts with the first given key" do
    data = { user: {
      id: "1234",
      email: "example@herou.com",
      full_name: "Full Name"
    }}
    coder = Identity::CookieCoder.new(secret)
    coder.encode(data)
    coder = Identity::CookieCoder.new(another_secret, secret)
    refute_equal data, coder.encode(data)
  end

  it "enables graceful encryption key rotation" do
    data = { user: {
      id: "1234",
      email: "example@herou.com",
      full_name: "Full Name"
    }}
    coder = Identity::CookieCoder.new(secret)
    cipher = coder.encode(data)
    coder = Identity::CookieCoder.new(another_secret, secret)

    assert_equal data, coder.decode(cipher)
  end
end
