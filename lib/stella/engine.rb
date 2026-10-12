# frozen_string_literal: true

module Stella
  # A theme is an engine like a plugin: its views and helpers join the app's,
  # and it registers with Website, which turns the public site on. Its
  # stylesheet, scripts, fonts and images are served by the theme itself
  # (Stella::AssetsController), as are the Astro site's public files
  # (/images/…, the favicons) that the CMS's content points at by path.
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
        # The Astro site's public/ directory, at the addresses its pages and the CMS's content use.
        get "images/*path", to: "stella/assets#public_file", format: false, as: :stella_public_image
        %w[favicon.ico favicon.svg apple-touch-icon.png].each do |file|
          get file, to: "stella/assets#public_file", defaults: {path: file}, format: false
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
      # no addresses for the testimonials (a collection with no pages).
      Cms::Plugins.filter(:stella, "sitemap.entries") do |entries|
        entries.filter_map do |entry|
          next if entry.collection_slug == "testimonials"

          entry.collection_slug == "posts" ? entry.dup.tap { it.loc = entry.loc.sub(%r{\A/posts/}, "/blog/") } : entry
        end
      end
    end
  end
end
