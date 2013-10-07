require_relative "identity/config"
require_relative "identity/csrf"
require_relative "identity/cookie"
require_relative "identity/cookie_fixer"
require_relative "identity/error_handling"
require_relative "identity/errors"
require_relative "identity/excon_instrumentor"
require_relative "identity/fernet_cookie_coder"
require_relative "identity/heroku_api"

require_relative "identity/log_helpers"
require_relative "identity/api_helpers"
require_relative "identity/auth_helpers"

require_relative "identity/middleware/heroku_cookie"

# modules
require_relative "identity/account"
require_relative "identity/assets"
require_relative "identity/auth"
require_relative "identity/default"

require_relative "identity/main"

module Identity
  # make sure we get an app=identity in every line that we log
  def self.log(action, data={}, &block)
    data.merge!(app: "identity")
    Slides.log(action, data, &block)
  end
end
