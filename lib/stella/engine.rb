# frozen_string_literal: true

module Stella
  # A theme is an engine like a plugin: its views and helpers join the app's,
  # and it registers with Website, which turns the public site on. Its
  # stylesheet, scripts, fonts and favicons are served by the theme itself
  # (Stella::AssetsController); every image the content shows is in the
  # CMS's media library.
  class Engine < ::Rails::Engine
    initializer "stella.importmap", before: "importmap" do |app|
      app.config.assets.paths << root.join("app/javascript")
    end

    # Ahead of the website's catch-all (appended once every initializer has
    # run). Each of these hands back to the catch-all when another theme is
    # drawing the site (Stella::WebsiteController).
    initializer "stella.routes" do |app|
      app.routes.append do
        get "_stella/*path", to: "stella/assets#show", format: false, as: :stella_asset
        %w[favicon.ico favicon.svg apple-touch-icon.png].each do |file|
          get file, to: "stella/assets#root_file", defaults: {path: file}, format: false
        end
        # Posts live at /blog/<slug>, as on the Astro site; the CMS's own address for them (/posts/<slug>) redirects there.
        get "blog/:slug", to: "stella/website#post", format: false, as: :stella_post
        get "posts/:slug", to: "stella/website#post_redirect", format: false
        # The Academy's static design preview (the Astro site's src/pages/academy).
        get "academy", to: "stella/website#academy", format: false, as: :stella_academy
        get "academy/login", to: "stella/website#academy_login", format: false, as: :stella_academy_login
        get "academy/signup", to: "stella/website#academy_signup", format: false, as: :stella_academy_signup
        get "academy/:slug", to: "stella/website#academy_item", format: false, as: :stella_academy_item
      end
    end

    config.to_prepare do
      # A plugin too, so Settings › Plugins installs it from its GitHub
      # release, updates it, and switches the site on and off.
      Cms::Plugins.register :stella, name: "Stella", version: Stella::VERSION,
        description: "The runstella.com website, as a theme: switch it off and the CMS is headless.",
        author: "Lumin", enabled_by_default: true, requires: ">= 1.30",
        homepage: "https://github.com/GoLumin/stella-theme"
      Website.register :stella, name: "Stella", version: Stella::VERSION,
        views: Stella::Engine.root.join("app/views"),
        importmap: Importmap::Map.new.draw(Stella::Engine.root.join("config/importmap.rb"))

      # The sitemap as the Astro site published it: posts at /blog/<slug>, and
      # entries only of the collections the theme draws pages for (the shared
      # lists — testimonials, features, FAQs, team, logos, pricing tiers — have none).
      Cms::Plugins.filter(:stella, "sitemap.entries") do |entries|
        drawn = Stella::Engine.root.glob("app/views/website/entries/*.html.erb").map { it.basename.to_s.delete_suffix(".html.erb") }
        entries.filter_map do |entry|
          next entry unless entry.collection_slug
          next unless drawn.include?(entry.collection_slug)

          entry.collection_slug == "posts" ? entry.dup.tap { it.loc = entry.loc.sub(%r{\A/posts/}, "/blog/") } : entry
        end
      end
    end
  end
end
