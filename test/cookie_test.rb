require_relative "test_helper"

describe Identity::Cookie do
  it "sets created_at on initialization" do
    Timecop.freeze(Time.now) do
      fake_session = {}
      cookie = Identity::Cookie.new(fake_session)
      assert_equal Time.now.to_i, cookie.created_at.to_i
      assert_equal Time.now.iso8601, fake_session["created_at"]
    end
  end
end
