# frozen_string_literal: true

# The Academy's static design preview (src/pages/academy, src/data/academyPreview.ts):
# representative library content, so the design shows without the members'
# backend (sign-in against D1, downloads through a proxy) the Astro site
# keeps on another branch. Copy from the academy_page global stays the CMS's.
module StellaAcademyHelper
  KIND_LABEL = {"article" => "Article", "file" => "Download", "audio" => "Recording", "link" => "Link"}.freeze

  ACADEMY_PREVIEW = [
    {slug: "onboarding-your-yard", title: "Onboarding your yard on Stella", kind: "article",
     summary: "The first-week playbook — loading inventory, mapping your service area, and taking your first booking end to end.",
     category: "Getting started", duration: "8 min read",
     body: "## Start with one real booking\n\nThe fastest way to get fluent is to run a single live job through the whole system — lead, quote, contract, delivery, invoice — rather than touring every screen.\n\n## Load inventory first\n\nUpload your containers and zip codes before anything else. Once the yard exists in Stella, every other workflow has something to attach to."},
    {slug: "migration-checklist", title: "Switching-software migration checklist", kind: "file",
     summary: "A printable checklist for moving inventory, customers and active agreements without dropping a booking.",
     category: "Getting started"},
    {slug: "dispatch-walkthrough", title: "Recorded: dispatch & delivery walkthrough", kind: "audio",
     summary: "Screen-shared session on scheduling drops, relocations and pickups so they land on the right calendar.",
     category: "Operations", duration: "24 min"},
    {slug: "multi-yard-inventory", title: "The multi-yard inventory playbook", kind: "article",
     summary: "What changes structurally when your containers live in more than one place, and how to keep the record honest.",
     category: "Operations", duration: "9 min read"},
    {slug: "billing-automation-deep-dive", title: "Recorded: billing automation deep-dive", kind: "audio",
     summary: "Recurring charges, transportation charges, refunds and declined-card recovery — set up once, run themselves.",
     category: "Billing", duration: "31 min"},
    {slug: "quickbooks-reconciliation", title: "QuickBooks reconciliation guide", kind: "file",
     summary: "How to close a month as a review instead of an audit, with the sync doing the double entry for you.",
     category: "Billing"},
    {slug: "website-booking-channel", title: "Turning your website into a booking channel", kind: "article",
     summary: "What it takes to let customers quote and reserve themselves — and the integration details that make or break it.",
     category: "Growth", duration: "8 min read"},
    {slug: "seasonal-pricing-worksheet", title: "Seasonal pricing & promotions worksheet", kind: "file",
     summary: "Model peak and off-peak rates against your own demand curve, and structure promotions that actually end.",
     category: "Growth"}
  ].map(&:freeze).freeze

  def stella_academy_items = ACADEMY_PREVIEW

  def stella_academy_item(slug) = ACADEMY_PREVIEW.find { it[:slug] == slug.to_s }

  # The library by category, in first-seen order.
  def stella_academy_groups = ACADEMY_PREVIEW.group_by { it[:category] }

  # The preview's tiny Markdown: "## " blocks as headings, the rest as
  # paragraphs, a block's line breaks as spaces.
  def stella_academy_body(markdown)
    safe_join(markdown.to_s.split(/\n{2,}/).filter_map do |block|
      text = block.strip
      next if text.empty?

      text.start_with?("## ") ? tag.h2(text[3..]) : tag.p(text.tr("\n", " "))
    end)
  end
end
