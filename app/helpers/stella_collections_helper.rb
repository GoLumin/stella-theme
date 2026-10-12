# frozen_string_literal: true

# The blog, case study and featured customer pages' own vocabulary
# (src/pages/blog, case-studies, featured-customers): posts newest first, the
# dates as the Astro site printed them, and a post's cover as its share image.
module StellaCollectionsHelper
  # The posts by date, newest first; posts on the same day keep their order.
  def stella_posts_by_date(posts = stella_posts)
    posts.each_with_index.sort_by { |post, index| [-stella_post_time(post[:date]), index] }.map(&:first)
  end

  def stella_post_time(date) = (Date.iso8601(date.to_s).to_time.to_i rescue 0)

  # "2026-06-18" → "June 18, 2026" (toLocaleDateString("en-US", long)).
  def stella_post_date(date)
    Date.iso8601(date.to_s).strftime("%B %-d, %Y")
  rescue Date::Error
    date.to_s
  end

  # The categories that have posts, in the collection's own order.
  def stella_active_categories(posts = stella_posts)
    StellaHelper::POST_CATEGORIES.select { |category| posts.any? { it[:category] == category } }
  end

  # A website address without its scheme ("https://acme.com/" → "acme.com").
  def stella_domain(url, trailing_slash: false)
    domain = url.to_s.sub(%r{\Ahttps?://}, "")
    trailing_slash ? domain.chomp("/") : domain
  end

  # The call to action on every post: the blog page's own fields (post_cta_*),
  # or nil without a live blog page.
  def stella_post_cta
    page = Page.live.find_by(path: "blog")
    page && website_fields(page)
  end

  # A post's <head>: its cover, when it has one, as the share image (Layout.astro's `image`).
  def stella_post_seo_tags(post)
    tags = stella_seo_tags(post[:entry], title: post[:title], description: post[:excerpt])
    share = stella_site[:share_image].presence
    return tags unless post[:cover] && share

    tags.sub(%(property="og:image" content="#{ERB::Util.html_escape(website_url(share))}"),
      %(property="og:image" content="#{ERB::Util.html_escape(website_url(post[:cover]))}")).html_safe # rubocop:disable Rails/OutputSafety -- website_seo_tags' own HTML, an escaped URL swapped in
  end
end
