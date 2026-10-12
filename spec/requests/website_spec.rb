# frozen_string_literal: true

require "rails_helper"

# The theme against the CMS it draws: spec/fixtures/cms/snapshot.json is the
# content model and live content of runstella.com (block types, collections,
# globals and forms with their fields, and every live page and entry). Every
# page and entry is drawn from it, so a template that reads a field the CMS
# doesn't declare (Website::Fields) or a form field the form doesn't have
# fails here. Refresh it with bin/pull <profile>, then bin/rails stella:snapshot.
RSpec.describe "The Stella website", type: :request, website: true do
  SNAPSHOT = JSON.parse(Stella::Engine.root.join("spec/fixtures/cms/snapshot.json").read)
  PARTIALS = Stella::Engine.root.glob("app/views/website/blocks/_*.html.erb").map { it.basename.to_s[/\A_(\w+)\./, 1] }
  ENTRY_TEMPLATES = Stella::Engine.root.glob("app/views/website/entries/*.html.erb").map { it.basename.to_s.delete_suffix(".html.erb") }
  GENERAL = SNAPSHOT["globals"].find { it["slug"] == "general" }["data"]
  NAME = GENERAL["name"]

  before do
    switch_plugin :forms, on: true
    SNAPSHOT["block_types"].each { BlockType.create!(it) }
    SNAPSHOT["collections"].each { Collection.create!(it) }
    SNAPSHOT["globals"].each { |global| Global.create!(global.except("fields").merge("schema" => {"fields" => global["fields"]})) }
    SNAPSHOT["forms"].each { Form.create!(it.merge("status" => "published")) }
    SNAPSHOT["pages"].each { Page.create!(it.merge("status" => "published")) }
    collections = Collection.all.index_by(&:slug)
    SNAPSHOT["entries"].each { collections.fetch(it["collection"]).entries.create!(it.except("collection").merge("status" => "published")) }
    Setting.set("general", SNAPSHOT["site"].merge("serving" => "website"))
  end

  def html = Nokogiri::HTML5(response.body)

  # Layout.astro's title: the site name after the page's, unless it's in it already.
  def title_for(title) = title.include?(NAME) ? title : "#{title} | #{NAME}"

  SNAPSHOT["pages"].reject { it["path"] == "not-found" }.each do |page|
    path = (page["path"] == "home") ? "/" : "/#{page["path"]}"

    it "draws #{path}, every one of its blocks" do
      get path

      expect(response).to have_http_status(:ok)
      expect(html.at_css("title").text).to eq(title_for(page["title"]))
      if (description = page.dig("seo", "description"))
        expect(html.at_css("meta[name=description]")["content"]).to eq(description)
      end
      page["blocks"].each { expect(PARTIALS).to include(it["type"]) }
    end
  end

  it "draws every post at /blog/<slug>, and sends the CMS's /posts/<slug> there" do
    posts = SNAPSHOT["entries"].select { it["collection"] == "posts" }
    expect(posts).not_to be_empty
    posts.each do |post|
      get "/blog/#{post["slug"]}"
      expect(response).to have_http_status(:ok), post["slug"]
      expect(html.at_css("h1").text).to include(post["title"].first(20))

      get "/posts/#{post["slug"]}"
      expect(response).to redirect_to("/blog/#{post["slug"]}")
      expect(response).to have_http_status(:moved_permanently)
    end
    get "/blog/no-such-post"
    expect(response).to have_http_status(:not_found)
  end

  %w[case-studies featured-customers].each do |collection|
    it "draws every #{collection} entry" do
      SNAPSHOT["entries"].select { it["collection"] == collection }.each do |entry|
        get "/#{collection}/#{entry["slug"]}"
        expect(response).to have_http_status(:ok), entry["slug"]
      end
    end
  end

  it "has no pages for the shared lists' entries" do
    %w[testimonials features faqs team integrations partners pricing-tiers].each do |collection|
      entry = SNAPSHOT["entries"].find { it["collection"] == collection }
      get "/#{collection}/#{entry["slug"]}"
      expect(response).to have_http_status(:not_found), collection
    end
  end

  it "has a partial only for block types the CMS has" do
    expect(PARTIALS - SNAPSHOT["block_types"].map { it["slug"] }).to be_empty
  end

  it "draws every block type it has a partial for, from the type's defaults" do
    blocks = SNAPSHOT["block_types"].select { PARTIALS.include?(it["slug"]) }.map { {"type" => it["slug"], "version" => it["version"], "data" => it["defaults"].to_h} }
    Page.new(slug: "every-block", path: "every-block", title: "Every block", status: "published", locale: "en", blocks:).save!(validate: false)

    get "/every-block"

    expect(response).to have_http_status(:ok)
  end

  it "draws its 404 from the CMS's not-found page, never indexed" do
    get "/no-such-page"

    expect(response).to have_http_status(:not_found)
    expect(html.at_css("title").text).to eq(title_for(SNAPSHOT["pages"].find { it["path"] == "not-found" }["title"]))
    expect(html.at_css("meta[name=robots]")["content"]).to start_with("noindex")
  end

  it "draws every page in the editor's preview, its short text marked for editing in place and its links unmarked" do
    sign_in_as create(:user)
    SNAPSHOT["pages"].each do |snapshot|
      page = Page.find_by!(path: snapshot["path"])
      blocks = page.blocks.each_with_index.to_h { |block, index| [index.to_s, {"_json" => block.to_json}] }
      patch page_path(page.path, website_preview: 1), params: {page: {title: page.title, slug: page.slug, status: "published", lock_version: page.lock_version, blocks:}}

      expect(response).to have_http_status(:ok), page.path
      expect(response.body).to include("⁣"), page.path unless page.blocks.empty?
      marked = html.css("[href], [action], [src]").select { (it["href"] || it["action"] || it["src"]).match?(/[⁣⁤​‌‍⁠]/) }
      expect(marked.map(&:to_html)).to be_empty, page.path
    end
  end

  it "follows Tools › Redirects" do
    redirect = SNAPSHOT["redirects"].first
    Redirect.create!(redirect)

    get redirect["source_path"]

    expect(response).to redirect_to(redirect["destination_url"])
  end

  it "draws the Academy preview" do
    %w[/academy /academy/login /academy/signup].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
    get "/academy/no-such-item"
    expect(response).to have_http_status(:not_found)
  end

  it "takes the header and footer from the nav, footer and general globals" do
    get "/"

    nav = SNAPSHOT["globals"].find { it["slug"] == "nav" }["data"]
    expect(html.css(".v2h-list > .v2h-item > .v2h-link").map { it.text.strip }).to eq(nav["items"].map { it["label"] })
    footer = SNAPSHOT["globals"].find { it["slug"] == "footer" }["data"]
    expect(html.css(".v2f-col .v2f-head").map(&:text)).to eq(footer["columns"].map { it["heading"] })
    expect(html.at_css(".rail-phone")["href"]).to eq(GENERAL["phone_href"])
  end

  it "posts the demo request to the Forms plugin with every field it draws" do
    get "/"
    form = html.at_css("form[data-cms-form=quick-demo]")
    names = form.css("input, select, textarea").map { it["name"] }.compact
    quick_demo = Form.find_by!(slug: "quick-demo")

    expect(names - quick_demo.fields.map { it["name"] }).to be_empty
    expect(form["data-honeypot"]).to eq(Form::HONEYPOT_FIELD)

    answers = {"name" => "Jordan Reyes", "company" => "Acme Mobile Storage", "email" => "jordan@example.com", "phone" => "(555) 555-5555"}
    post form["action"], params: answers, as: :json
    expect(response).to have_http_status(:created)
    expect(FormSubmission.last.data).to include("email" => "jordan@example.com")

    post form["action"], params: answers.except("email"), as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "draws every CMS form it posts to with fields that form declares" do
    SNAPSHOT["pages"].each do |page|
      get((page["path"] == "home") ? "/" : "/#{page["path"]}")
      html.css("form[data-cms-form]").each do |form|
        declared = Form.find_by!(slug: form["data-cms-form"]).fields.map { it["name"] }
        expect(form.css("input, select, textarea").filter_map { it["name"] } - declared).to be_empty, "#{page["path"]}: #{form["data-cms-form"]}"
      end
    end
  end

  it "shows Cloudflare Turnstile on its forms when Settings › Forms has the keys, and loads it only then" do
    get "/"
    expect(response.body).not_to include("cf-turnstile", "challenges.cloudflare.com")

    Setting.set(Forms::SETTING_KEY, {"captcha_provider" => "turnstile", "turnstile_site_key" => "0x4AAA-site", "turnstile_secret_key" => "0x4AAA-secret"})
    get "/"

    expect(html.at_css("form[data-cms-form] .cf-turnstile")["data-sitekey"]).to eq("0x4AAA-site")
    expect(response.body.scan("challenges.cloudflare.com/turnstile/v0/api.js").size).to eq(1)
  end

  it "designs the form's emails, filled in per submission" do
    form = Form.find_by!(slug: "contact")
    email = form.emails.find_or_initialize_by(kind: "confirmation")
    email.update!(subject: "Thanks, {{name}}", enabled: true, blocks: [
      {"type" => "email_heading", "version" => 1, "data" => {"text" => "Thank you, {{name}}", "level" => "h1"}},
      {"type" => "email_submission", "version" => 1, "data" => {"title" => "What you sent", "skip_empty" => true}}
    ])
    submission = form.submissions.create!(data: {"name" => "Ann", "email" => "ann@example.com", "message" => "A <b>quote</b>"}, meta: {}, ip: "127.0.0.1")

    mail = FormSubmissionMailer.with(form_email: email, submission:, recipients: ["ann@example.com"]).deliver.message
    body = (mail.html_part || mail).body.decoded

    expect(email.site_template_status).to eq(:theme)
    expect(mail.subject).to eq("Thanks, Ann")
    expect(body).to include("Thank you, Ann", NAME)
    expect(body.scan("data-cms-repeat").size + body.scan("{{").size).to eq(0)
  end

  it "lists posts at /blog/<slug> in the sitemap, and nothing from the collections without pages" do
    get "/sitemap.xml"

    locs = Nokogiri::XML(response.body).remove_namespaces!.css("loc").map(&:text)
    expect(locs.grep(%r{/posts/})).to be_empty
    expect(locs.grep(%r{/blog/.+})).not_to be_empty
    %w[testimonials features faqs team integrations partners pricing-tiers].each { |slug| expect(locs.grep(%r{/#{slug}/})).to be_empty, slug }
  end

  it "reads the shared lists from their collections, in their order" do
    get "/pricing"
    tiers = SNAPSHOT["entries"].select { it["collection"] == "pricing-tiers" }.sort_by { it.dig("frontmatter", "order") }
    expect(html.css(".tier-name").map { it.text.strip }).to eq(tiers.map { it["title"] })

    get "/faq"
    categories = SNAPSHOT["entries"].select { it["collection"] == "faqs" }.sort_by { it.dig("frontmatter", "order") }.map { it.dig("frontmatter", "category") }.uniq
    expect(html.css(".group-title").map { it.text.strip }).to eq(categories)
  end

  it "serves its own scripts, stylesheet and fonts, and the Astro site's public files, with nothing compiled" do
    get "/"
    page = html

    importmap = JSON.parse(page.at_css("script[type=importmap]").text)["imports"]
    expect(importmap.keys).to all(start_with("stella/"))
    expect(importmap.values).to all(start_with("/_stella/"))
    expect(response.body).not_to include("/assets/application-", "/assets/stella/")

    stylesheet = page.at_css("link[rel=stylesheet]")["href"]
    get stylesheet
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.headers["Cache-Control"]).to include("immutable")
    expect(response.body).to include('url("archivo.woff2")')

    (importmap.values + page.css("link[as=font]").map { it["href"] }).each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
    %w[/favicon.ico /favicon.svg /apple-touch-icon.png /images/logo/logo-stella.svg /images/share/stella.png].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
    end
    ["/_stella/../../stella.gemspec", "/_stella/README.md", "/images/../stella.gemspec", "/images/nope.png"].each do |path|
      get path
      expect(response).to have_http_status(:not_found), path
    end
  end
end
