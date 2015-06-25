module Identity
  class HerokuFidClient
    def initialize(url: Config.heroku_fid_url)
      @url = url
    end

    def get_redirect_url_for(org_name)
      request_json(
        method: "GET",
        path: "/saml/#{org_name}/redirect-info",
        expects: 200,
        headers: default_headers
      ).fetch("url")
    end

    def authenticate(org_name, saml_response)
      request_json(
        body: MultiJson.dump(saml: saml_response),
        path: "/saml/#{org_name}/authenticate",
        method: "POST",
        expects: 201,
        headers: default_headers
      )
    end

    private

    def connection
      @connection ||= Excon.new(@url)
    end

    def default_headers
      {
        "Accept"       => "application/json",
        "Content-Type" => "application/json"
      }
    end

    def request_json(**params)
      MultiJson.load(connection.request(params).body)
    end
  end
end
