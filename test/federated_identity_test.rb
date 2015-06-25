require_relative "test_helper"

describe Identity::FederatedIdentity do
  include Rack::Test::Methods

  def request_session
    last_request.env["rack.session"]
  end

  def app
    Sinatra.new do
      use Rack::Session::Cookie, domain: "example.org", secret: "my-secret"
      use Identity::FederatedIdentity
    end
  end

  before do
    rack_mock_session.clear_cookies
  end

  it "redirects on init stage" do
    any_instance_of(Identity::HerokuFidClient) do |fid_client|
      stub(fid_client).get_redirect_url_for do |org_name|
        assert_equal "acme", org_name
        { "url" => "http://example.com/sso" }
      end
    end

    get "/federated/acme/saml/init"

    assert last_response.redirect?
    assert "http://example.com/sso", last_response["Location"]
  end

  it "creates authentication on finalize step" do
    any_instance_of(Identity::HerokuFidClient) do |fid_client|
      stub(fid_client).authenticate do |org_name, saml|
        assert_equal "<saml-resp>", saml
        assert_equal "acme", org_name

        {"access_token"=>
         {"expires_in"=>28799,
          "id"=>"d8b2a710-19bf-4640-b4aa-695c7424cebc",
          "token"=>"1c18eb5a-112b-4c29-9691-fac13d984a40"},
          "client"=>
         {"id"=>"c9d106c7-d9ba-417a-93fd-97b6f20be0f3",
          "ignores_delinquent"=>nil,
          "name"=>"fido",
          "redirect_uri"=>"https://fido.dev"},
          "created_at"=>"2015-06-12T18:21:09Z",
          "description"=>"fido",
          "grant"=>nil,
          "id"=>"e94432c3-6302-4944-ad4d-54ccecb78465",
          "refresh_token"=>
         {"expires_in"=>nil,
          "id"=>"08ee5e2f-c347-466b-9366-adfde6e108ca",
          "token"=>"7811d1ea-e265-4a51-9b46-ff783c9fcd89"},
          "session"=>{"id"=>"e546208d-3dd8-45f6-9bbc-07e8902895a1"},
          "scope"=>["global"],
          "updated_at"=>"2015-06-12T18:21:09Z",
          "user"=>{"id"=>"76ee2d4b-3fbf-4586-830d-71e507513180"}}
      end
    end

    post "/federated/acme/saml/finalize", SAMLResponse: "<saml-resp>"

    assert_equal request_session["oauth_session_id"], "e546208d-3dd8-45f6-9bbc-07e8902895a1"
    assert_equal request_session["access_token"],     "1c18eb5a-112b-4c29-9691-fac13d984a40"

    assert last_response.redirect?
    assert Identity::Config.dashboard_url, last_response["Location"]
  end
end
