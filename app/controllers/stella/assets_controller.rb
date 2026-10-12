# frozen_string_literal: true

module Stella
  # The theme's own files (its stylesheet, scripts and fonts) at
  # /_stella/<name>, and the Astro site's public files (/images/…, the
  # favicons) at the addresses its pages and the CMS's content use, served
  # from the theme rather than through the asset pipeline: a theme installed
  # from Settings › Plugins would otherwise depend on the install compiling
  # its assets when it boots. Theme files carry their digest in the address
  # (StellaHelper#stella_asset_path), so each can be cached for good.
  class AssetsController < ActionController::Base
    TYPES = {".css" => "text/css", ".js" => "text/javascript", ".woff2" => "font/woff2", ".webp" => "image/webp",
             ".png" => "image/png", ".svg" => "image/svg+xml", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
             ".gif" => "image/gif", ".ico" => "image/x-icon", ".avif" => "image/avif"}.freeze

    # Public, static files: no session, and scripts load from <script type="module">
    # (Rails would otherwise refuse a .js response to a GET as cross-origin).
    skip_forgery_protection

    # The asked-for name is only compared with the index's names: the file
    # sent is always one of the theme's.
    def show
      send_indexed(self.class.files[params[:path].to_s], immutable: params[:v].present?)
    end

    def public_file
      wanted = request.path.delete_prefix("/")
      send_indexed(self.class.public_files[wanted] || self.class.public_files[CGI.unescape(wanted)], immutable: false)
    end

    # Every file the theme serves, by its name ("site.css", "archivo.woff2"):
    # the theme's own asset directories, indexed once. A name is only ever
    # looked up here, never turned into a path.
    DIRECTORIES = %w[app/assets/stylesheets/stella app/assets/fonts/stella app/javascript/stella]
      .map { Stella::Engine.root.join(it) }.freeze
    PUBLIC = Stella::Engine.root.join("public")

    # Indexed once in production; looked at afresh elsewhere, so a file added
    # while working on the theme is served without a restart.
    def self.files
      Rails.env.production? ? (@files ||= index(DIRECTORIES)) : index(DIRECTORIES)
    end

    # public/, by path ("images/blog/x/photo.jpg", "favicon.ico").
    def self.public_files
      Rails.env.production? ? (@public_files ||= index([PUBLIC])) : index([PUBLIC])
    end

    def self.find(name) = files[name.to_s]

    def self.index(directories)
      directories.reverse.each_with_object({}) do |directory, index|
        directory.glob("**/*").select { it.file? && TYPES.key?(it.extname.downcase) }.each { index[it.relative_path_from(directory).to_s] = it }
      end.freeze
    end

    private

    def send_indexed(file, immutable:)
      return head(:not_found) unless file

      response.headers["Cache-Control"] = immutable ? "public, max-age=31536000, immutable" : "public, max-age=3600"
      response.headers["Access-Control-Allow-Origin"] = "*" if file.extname == ".woff2"
      send_file(file, type: TYPES.fetch(file.extname.downcase, "application/octet-stream"), disposition: :inline)
    end
  end
end
