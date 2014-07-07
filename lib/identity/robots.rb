module Identity
  class Robots < Sinatra::Base
    register ErrorHandling

    get "/robots.txt" do
      content_type :text
      <<-eos
# Won't actually prevent these folders from appearing in a search engine's
# index, but isn't really harmful either.
User-agent: *
Disallow: /account/email/confirm/
Disallow: /account/password/reset/
      eos
    end
  end
end
