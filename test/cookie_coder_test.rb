require_relative "test_helper"

describe Identity::CookieCoder do
  it "encryptes a cookie, then descripts a cookie" do
    data = { user: { id: "1234", email: "example@herou.com", full_name: "Full Name" }}
    coder = Identity::CookieCoder.new("my-key" * 20)
    cipher = coder.encode(data)

    assert_equal JSON.parse(JSON.generate(data)), coder.decode(cipher)
  end

  it "encrypts with the first given key" do
    data = { "user" => { "id" => "1234", "email" => "example@herou.com", "full_name" => "Full Name" }}
    coder = Identity::CookieCoder.new("my-key" * 20)
    coder.encode(data)
    coder = Identity::CookieCoder.new("my-new-key" * 20, "my-key" * 20)

    refute_equal data, coder.encode(data)
  end

  it "enables graceful encryption key rotation" do
    data = { "user" => { "id" => "1234", "email" => "example@herou.com", "full_name" => "Full Name" }}
    coder = Identity::CookieCoder.new("my-key" * 20)
    cipher = coder.encode(data)
    coder = Identity::CookieCoder.new("my-new-key" * 20, "my-key" * 20)

    assert_equal data, coder.decode(cipher)
  end
end
