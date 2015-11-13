require_relative "../test_helper"

describe Identity::Helpers::API do
  include Identity::Helpers::API

  describe :decode_error do
    before do
      stub(self).log
    end

    it "returns the message value for v3 error messages" do
      error = {
        id:      "rate_limit",
        message: "Please wait a few minutes before making new requests"
      }
      assert_equal error[:message], decode_error(MultiJson.encode(error))
    end

    it "merges any other hashes it gets back" do
      error = {
        id:    "wat",
        error: "something weird"
      }
      assert_equal "id wat; error something weird", decode_error(MultiJson.encode(error))
    end

    it "falls through in the case of decoding errors" do
      assert_equal "that's some error", decode_error("that's some error")
    end
  end
end
