module Identity
  class Robots < Sinatra::Base
    register ErrorHandling

    get "/robots.txt" do
      content_type :text
      <<-eos
User-agent: *
Disallow: /account/email/confirm/
Disallow: /account/password/reset/
      eos
    end
  end
end
