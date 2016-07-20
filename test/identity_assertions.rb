def assert_response_redirects_with_oauth_callback(state: nil)
  assert_equal 302, last_response.status
  base = HerokuAPIStub::AUTHORIZATION[:client][:redirect_uri]
  code = HerokuAPIStub::AUTHORIZATION[:grant][:code]
  state = !state.nil? ? "&state=#{state}" : ""
  assert_equal "#{base}?code=#{code}#{state}", last_response.headers["Location"]
end
