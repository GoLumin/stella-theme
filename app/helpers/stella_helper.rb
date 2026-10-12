# frozen_string_literal: true

# The theme's vocabulary on top of WebsiteHelper: the Astro site's data
# modules (src/data/*.ts, which scripts/sync-data.mjs built from these same
# globals and collections) as the templates read them, its text rule (CMS
# values are copy: rich text is flattened to plain text, src/lib/richtext.mjs),
# its forms, and the theme's own files.
module StellaHelper
  # ── Text ─────────────────────────────────────────────────────────────────

  # A CMS value as the Astro site's `str()` reads it: a string ("" when it's
  # anything else), with any rich-text HTML flattened to plain text, or the
  # fallback when that's empty.
  def stella_str(value, fallback = "")
    text = value.is_a?(String) ? stella_flatten(value) : ""
    text.empty? ? fallback : text
  end

  # A list field as strings (the Astro site's `list()`).
  def stella_list(value) = Array(value).map { stella_str(it) }

  # src/lib/richtext.mjs: HTML (what the rich-text editor stores) as plain
  # text, paragraphs and line breaks as newlines; a plain string as it is.
  RICH_TEXT_TAG = %r{</?[a-z][^>]*>}i
  BLOCK_CLOSE = %r{</(?:p|div|li|ul|ol|h[1-6]|blockquote|figure|tr)>}i

  def stella_flatten(text)
    return text unless text.match?(RICH_TEXT_TAG)

    text = text.gsub(%r{<br\s*/?>}i, "\n").gsub(BLOCK_CLOSE, "\n").gsub(%r{</?[a-z][^>]*>}i, "")
    CGI.unescapeHTML(text).tr("\u00a0", " ").gsub(/[ \t]+\n/, "\n").gsub(/\n{3,}/, "\n\n").strip
  end

  # A text field's value with one phrase picked out: [before, phrase, after],
  # or nil when the phrase isn't in it (a hero's lede and its highlight).
  def stella_split(text, phrase)
    phrase = phrase.to_s.strip
    at = phrase.empty? ? nil : text.index(phrase)
    at && [text[0, at], phrase, text[(at + phrase.length)..]]
  end

  # An address typed into a text field, for an href. In the editor's preview
  # a text field carries its inline-edit markers (Website::InlineEdit); an
  # address is followed, not edited in place, so they come off.
  def stella_href(url)
    url = stella_str(url).delete(INLINE_EDIT_MARKS).strip
    url if url.present? && SafeUrl.safe?(url)
  end
  INLINE_EDIT_MARKS = [Website::InlineEdit::START, Website::InlineEdit::FINISH, *Website::InlineEdit::DIGITS].join

  # ── src/data/site.ts ─────────────────────────────────────────────────────

  SITE_FIELDS = %i[name tagline topbar_tagline description phone phone_href login_url demo_url starting_price founded_year share_image].freeze

  # The `general` global (the business's identity, phone and pricing).
  def stella_site
    @stella_site ||= SITE_FIELDS.to_h { [it, stella_str(website_global(:general)[it])] }
  end

  # The header's menu: a plain link, or one with a mega panel (columns and an
  # optional feature card). `mega` is absent for a plain link, as in site.ts.
  def stella_nav
    @stella_nav ||= website_global(:nav).items.map do |item|
      columns = stella_columns(item.columns)
      eyebrow = stella_str(item.feature_eyebrow)
      link = {label: stella_str(item.label), href: stella_str(item.href)}
      next link if columns.empty? && eyebrow.empty?

      feature = unless eyebrow.empty?
        {eyebrow:, title: stella_str(item.feature_title), body: stella_str(item.feature_body),
         href: stella_str(item.feature_href), cta: stella_str(item.feature_cta)}
      end
      link.merge(mega: {columns:, feature:})
    end
  end

  def stella_footer_nav = @stella_footer_nav ||= stella_columns(website_global(:footer).columns)

  def stella_footer_disclaimer = stella_str(website_global(:footer).disclaimer)

  def stella_footer_consent_label = stella_str(website_global(:footer).consent_link_label)

  def stella_columns(columns)
    columns.map do |column|
      links = column.links.map { {label: stella_str(it.label), href: stella_str(it.href), desc: stella_str(it.desc).presence}.compact }
      {heading: stella_str(column.heading), links:}
    end
  end

  # ── src/data/content.ts ──────────────────────────────────────────────────

  def stella_features
    @stella_features ||= website_global(:features).items.map do |item|
      {id: stella_str(item.id), icon: stella_str(item.icon), title: stella_str(item.title), short: stella_str(item.short),
       body: stella_str(item.body), points: stella_list(item.points)}
    end
  end

  def stella_integrations = @stella_integrations ||= stella_logos(website_global(:integrations).items, href: false)

  def stella_partners = @stella_partners ||= stella_logos(website_global(:partners).items, href: true)

  def stella_logos(items, href:)
    items.map do |item|
      {name: stella_str(item.name), src: stella_str(item.src), href: (stella_str(item.href).presence if href), note: stella_str(item.note).presence}.compact
    end
  end

  def stella_team
    @stella_team ||= website_global(:team).items.map do |item|
      {name: stella_str(item.name), role: stella_str(item.role), photo: stella_str(item.photo).presence,
       email: stella_str(item.email).presence, bio: stella_str(item.bio).presence}.compact
    end
  end

  def stella_base_features = stella_list(website_global(:pricing).base_features)

  def stella_tiers
    @stella_tiers ||= website_global(:pricing).tiers.map do |tier|
      {name: stella_str(tier.name), price: stella_str(tier.price), cadence: stella_str(tier.cadence), blurb: stella_str(tier.blurb),
       cta: stella_str(tier.cta), featured: (true if website_truthy?(tier.featured)), badge: stella_str(tier.badge).presence,
       inherits: stella_str(tier.inherits).presence, features: stella_list(tier.features)}.compact
    end
  end

  def stella_faqs
    @stella_faqs ||= website_global(:faqs).items.map { {q: stella_str(it.q), a: stella_str(it.a), category: stella_str(it.category)} }
  end

  # ── Collections (src/data/testimonials.ts, posts.ts, caseStudies.ts, featuredCustomers.ts)

  # A collection's published entries in their `order`, as the sync sorted them.
  def stella_entries(collection) = website_entries(collection)

  def stella_testimonials
    @stella_testimonials ||= stella_entries(:testimonials).map do |entry|
      fields = website_fields(entry)
      {quote: stella_str(fields.quote), name: stella_str(fields.name), role: stella_str(fields.role).presence, company: stella_str(fields.company),
       location: stella_str(fields.location).presence, logo: stella_str(fields.logo).presence, featured: (true if website_truthy?(fields.featured))}.compact
    end
  end

  def stella_featured_testimonials = stella_testimonials.select { it[:featured] }

  POST_CATEGORIES = %w[Operations Growth Billing Industry Product].freeze

  def stella_posts = @stella_posts ||= stella_entries(:posts).map { stella_post(it) }

  def stella_post(entry)
    fields = website_fields(entry)
    {slug: entry.slug, title: stella_str(entry.title), excerpt: stella_str(fields.excerpt), category: stella_str(fields.category),
     author: stella_str(fields.author), date: stella_str(fields.date), reading_time: stella_str(fields.reading_time),
     tags: stella_list(fields.tags), cover: stella_str(fields.cover).presence, entry:,
     body: fields.body.map do |section|
       {heading: stella_str(section.heading), image: stella_str(section.image).presence, image_alt: stella_str(section.image_alt).presence,
        paragraphs: stella_list(section.paragraphs), list: stella_list(section.list).presence}.compact
     end}.compact
  end

  def stella_case_studies = @stella_case_studies ||= stella_entries(:"case-studies").map { stella_case_study(it) }

  def stella_case_study(entry)
    fields = website_fields(entry)
    {slug: entry.slug, company: stella_str(fields.company), location: stella_str(fields.location).presence, logo: stella_str(fields.logo).presence,
     website: stella_str(fields.website).presence, summary: stella_str(fields.summary), challenge: stella_str(fields.challenge),
     solution: stella_str(fields.solution), results: stella_list(fields.results), quote: stella_str(fields.quote),
     attribution: stella_str(fields.attribution), modules: stella_list(fields.modules), entry:}.compact
  end

  def stella_featured_customers = @stella_featured_customers ||= stella_entries(:"featured-customers").map { stella_featured_customer(it) }

  def stella_featured_customer(entry)
    fields = website_fields(entry)
    {slug: entry.slug, company: stella_str(fields.company), location: stella_str(fields.location).presence, logo: stella_str(fields.logo).presence,
     image: stella_str(fields.image).presence, website: stella_str(fields.website).presence, summary: stella_str(fields.summary),
     highlights: stella_list(fields.highlights), customer_since: stella_str(fields.customer_since).presence,
     quote: stella_str(fields.quote).presence, attribution: stella_str(fields.attribution).presence,
     body: entry.body_markdown.presence, entry:}.compact
  end

  # ── src/data/pages.ts: a page-copy global (blog, case_studies_page, …) ──

  def stella_page_copy(slug) = website_global(slug)

  # ── src/data/forms.ts ────────────────────────────────────────────────────

  # A published CMS form as the markup needs it: where it posts (the Forms
  # plugin's public endpoint, or the form's own), its button and thank-you.
  # `fields` names the inputs the markup draws; each must be one the form
  # declares (website_form_field), or the CMS would drop it.
  def stella_form(slug, fields: [])
    form = defined?(Form) && Form.find_by(slug: slug.to_s, status: "published")
    fields.each { website_form_field(form, it) } if form
    {submit_url: form&.submit_url.presence || api_form_submissions_path(form_slug: slug.to_s),
     submit_label: form&.submit_label.to_s, success_message: form&.success_message.to_s, form:}
  end

  # Cloudflare Turnstile ({site_key:, theme:}) when Settings › Forms has it
  # set up (the Forms plugin then refuses a submission without its token),
  # else nil.
  def stella_turnstile
    captcha = Forms.public_captcha if defined?(Forms) && Forms.respond_to?(:public_captcha)
    {site_key: captcha[:site_key], theme: captcha[:theme] || "auto"} if captcha && captcha[:provider] == "turnstile"
  end

  # ── The <head> ───────────────────────────────────────────────────────────

  # Layout.astro's title: the site name after a page's title, unless it's
  # already in it (the home page's "Stella — …").
  def stella_title(title)
    name = stella_site[:name]
    return "#{name} — #{stella_site[:tagline]}" if title.blank?

    title.include?(name) ? title : "#{title} | #{name}"
  end

  # The <head> for a page or entry: the SEO panel's tags (website_seo_tags),
  # with the title and description the Astro site gave it, and the share
  # image from the `general` global when the record has none of its own.
  def stella_seo_tags(record = nil, title: nil, description: nil, noindex: nil)
    seo = record.respond_to?(:seo) ? record.seo.to_h.stringify_keys : {}
    description = description.presence || seo["description"].presence || stella_site[:description]
    noindex = website_truthy?(seo["noindex"]) if noindex.nil?
    tags = website_seo_tags(record, title: stella_title(title || record&.title), description:, noindex:)
    share = stella_site[:share_image].presence
    return tags if share.nil? || tags.include?('property="og:image"')

    safe_join([tags.sub('name="twitter:card" content="summary"', 'name="twitter:card" content="summary_large_image"').html_safe, # rubocop:disable Rails/OutputSafety -- website_seo_tags' own HTML
      tag.meta(property: "og:image", content: website_url(share))], "\n")
  end

  # ── The theme's own files ────────────────────────────────────────────────

  # A file of the theme's ("site.css", "archivo.woff2") at the address the
  # theme serves it from, with its digest, so browsers and caches keep it for
  # good and a changed file gets a new address (Stella::AssetsController).
  def stella_asset_path(name)
    file = Stella::AssetsController.find(name) || raise(ArgumentError, "no theme file #{name}")
    digest = (STELLA_DIGESTS[[name, file.mtime.to_i]] ||= Digest::SHA1.file(file).hexdigest[0, 10])
    "/_stella/#{name}?v=#{digest}"
  end
  STELLA_DIGESTS = {} # rubocop:disable Style/MutableConstant

  # The site's scripts as ES modules: an importmap of the theme's own files
  # (every module in app/javascript/stella, served by the theme), and one
  # module that imports them all. Each is the script of the Astro component
  # it's named for and does nothing on a page without that component.
  # Instead of website_javascript_tags, which needs the files compiled into
  # the asset pipeline.
  def stella_javascript_tags
    names = Stella::AssetsController.files.keys.grep(/\A[\w-]+\.js\z/).sort.map { it.delete_suffix(".js") }
    imports = names.to_h { ["stella/#{it}", stella_asset_path("#{it}.js")] }
    nonce = content_security_policy_nonce
    safe_join([
      tag.script(ERB::Util.json_escape({imports:}.to_json).html_safe, type: "importmap", nonce:), # rubocop:disable Rails/OutputSafety -- our own paths, JSON-escaped
      tag.script(names.map { "import \"stella/#{it}\"" }.join("\n").html_safe, type: "module", nonce:) # rubocop:disable Rails/OutputSafety -- our own module names
    ], "\n")
  end

  # The footer's copyright year.
  def stella_year = Time.current.year
end
