module Identity
  class Assets < Sinatra::Base
    register Identity::ErrorHandling

    def initialize(*args)
      super
      path = "#{Config.root}/assets"
      @assets = Sprockets::Environment.new do |env|
        Identity.log :assets, path: path

        env.append_path(path + "/fonts")
        env.append_path(path + "/images")
        env.append_path(path + "/javascripts")
        env.append_path(path + "/stylesheets")

        if Config.production?
          env.js_compressor  = YUI::JavaScriptCompressor.new
          env.css_compressor = YUI::CssCompressor.new
        end
      end
    end

    get "/assets/:release/classic.css" do
      content_type("text/css")
      respond_with_asset(@assets["classic.css"])
    end

    get "/assets/:release/classic.js" do
      content_type("application/javascript")
      respond_with_asset(@assets["classic.js"])
    end

    get "/assets/:release/zen-backdrop.css" do
      content_type("text/css")
      respond_with_asset(@assets["zen_backdrop.css"])
    end

    get "/assets/:release/zen-backdrop.js" do
      content_type("application/javascript")
      respond_with_asset(@assets["zen_backdrop.js"])
    end

    (%w{ico jpg png} + %w{eot svg ttf woff}).each do |format|
      get "/assets/*.#{format}" do |image|
        name = "#{image}.#{format}"
        if @assets[name]
          content_type("image/#{format}")
          respond_with_asset(@assets[name])
        else
          404
        end
      end
    end

    private

    def respond_with_asset(asset)
      last_modified(asset.mtime.utc)
      asset
    end
  end
end
