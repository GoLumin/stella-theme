# frozen_string_literal: true

namespace :stella do
  # The theme's spec draws every page from spec/fixtures/cms/snapshot.json.
  # This refreshes it from the content this install holds: pull the live
  # site first (bin/pull <profile>), so a change to the content model there
  # shows up as a failing spec here before it shows up as a broken page.
  # Live content only, and no one's personal details (no submissions).
  desc "Refresh spec/fixtures/cms/snapshot.json from this install's content (after bin/pull)"
  task snapshot: :environment do
    keep = ->(record, *keys) { record.attributes.slice(*keys) }
    snapshot = {
      "block_types" => BlockType.order(:slug).map { keep.(it, "slug", "label", "category", "version", "fields", "defaults") },
      "collections" => Collection.order(:slug).map { keep.(it, "slug", "name", "enable_blocks", "schema") },
      "globals" => Global.order(:slug).map { keep.(it, "slug", "name", "data").merge("fields" => it.fields) },
      "pages" => Page.live.order(:path).map { keep.(it, "path", "slug", "title", "locale", "blocks", "frontmatter", "seo") },
      "entries" => CollectionEntry.live.includes(:collection).sort_by { [it.collection.slug, it.id] }.map do |entry|
        keep.(entry, "slug", "title", "locale", "frontmatter", "body_markdown", "seo", "published_at").merge("collection" => entry.collection.slug)
      end,
      "forms" => (defined?(Form) ? Form.where(status: "published").order(:slug).map { keep.(it, "slug", "title", "fields", "submit_label", "success_message") } : []),
      "redirects" => Redirect.order(:source_path).map { keep.(it, "source_path", "destination_url", "status_code", "active") },
      "site" => Setting.get("general").slice("title", "description", "site_base_url")
    }
    path = Stella::Engine.root.join("spec/fixtures/cms/snapshot.json")
    path.write(JSON.pretty_generate(snapshot))
    puts "#{path}: #{snapshot.transform_values(&:size).to_h}"
  end
end
