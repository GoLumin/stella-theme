# frozen_string_literal: true

module Stella
  # The addresses the Astro site had that the CMS's own don't give: a post at
  # /blog/<slug> (the CMS would put it at /posts/<slug>, which redirects here),
  # the Academy's static design preview, and the SMS short links (/l/<hash>). Drawn like any website page
  # (Website::PagesController: cached, ?preview for editors); while another
  # theme draws the site, or none does, each address is the catch-all's again.
  class WebsiteController < Website::PagesController
    # /blog/<slug>: the posts entry.
    def post
      return show unless stella?
      return redirect_to(request.path.chomp("/"), status: :moved_permanently) if trailing_slash?

      posts = Collection.find_by(slug: "posts")&.entries
      entry = posts && (previewing? ? posts : posts.live).find_by(slug: params[:slug])
      entry ? render_record("website/entries/posts", entry:) : not_found(Website::Address.new(request.path))
    end

    # /posts/<slug>: where the CMS addresses a post, sent on to /blog/<slug>.
    def post_redirect
      return show unless stella?

      redirect_to "/blog/#{ERB::Util.url_encode(params[:slug])}#{"?#{request.query_string}" if request.query_string.present?}", status: :moved_permanently
    end

    def academy = academy_page("website/academy/index")

    def academy_login = academy_page("website/academy/login")

    def academy_signup = academy_page("website/academy/signup")

    def academy_item
      item = helpers.stella_academy_item(params[:slug])
      item ? academy_page("website/academy/item", item:) : (stella? ? not_found(Website::Address.new(request.path)) : show)
    end

    # /l/<hash>: an SMS short link, sent on to the work order it stands for.
    # Like the old site's, any failure lands on the home page rather than an
    # error: the person tapped a link in a text message and can do nothing
    # about a broken API. Never cached: each hash is one customer's.
    def short_link
      return show unless stella?

      destination = begin
        Stella::ShortLink.resolve(params[:hash])
      rescue Stella::ShortLink::Error => e
        Rails.logger.error("[sms-link] #{params[:hash]}: #{e.message}")
        "/"
      end

      response.headers["Cache-Control"] = "private, no-store"
      response.headers["X-Robots-Tag"] = "noindex"
      redirect_to destination, status: :found, allow_other_host: true
    end

    private

    def stella? = Website.enabled? && Website.theme&.key.to_s == "stella"

    def trailing_slash?
      path = request.original_fullpath.split("?").first
      path.length > 1 && path.end_with?("/")
    end

    # A page of the theme's own (no CMS record behind it): cached like a
    # published page, against the content and the theme.
    def academy_page(template, **locals)
      return show unless stella?
      return redirect_to(request.path.chomp("/"), status: :moved_permanently) if trailing_slash?

      expires_in 1.minute, public: true, stale_while_revalidate: 1.day
      render(template, locals:) if stale?(etag: [Website.cache_version, template, locals.values], public: true)
    end
  end
end
