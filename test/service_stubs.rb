require_relative "service_stubs/heroku_api_stub"

def stub_service(uri, stub, &block)
  uri = URI(uri)
  uri.user, uri.password = nil, nil
  stub = block ? Sinatra.new(stub, &block) : stub
  stub_request(:any, /^#{uri}\/.*$/).to_rack(stub)
end

def stub_heroku_api(&block)
  stub_service(Identity::Config.heroku_api_url, HerokuAPIStub, &block)
end
