# Stella theme

runstella.com, drawn by Libre Publish: the site's layout, a partial per
block type, the blog, case study and featured customer pages, the Academy
preview, its form emails, and its stylesheet and scripts. Plain ERB and CSS
and an importmap; nothing is built. How themes work: Libre Publish's
docs/themes.md.

It is the Astro site ([stella-marketing](https://github.com/GoLumin/stella-marketing)),
one for one: the same markup, classes, copy and CSS, drawn from the same CMS
content. The stylesheet is the Astro build's CSS: the global layer as
written, then each component's scoped rules as Astro compiles them, with
Astro's `data-astro-cid-<hash>` scope renamed `data-c-<component>` (every
element a component draws carries it, as in the Astro build). The ROI
calculator, a Svelte island there, is plain markup and a module here. Fonts
(Archivo, Inter, IBM Plex Mono) are served from the theme, not Google.

## What draws what

| Address | From |
| --- | --- |
| `/`, `/about`, `/pricing`, … every CMS page | the page's blocks, in order (`app/views/website/blocks/_<type>`) |
| `/blog`, `/case-studies`, `/featured-customers` | the page's blocks too: an index block (`stl_blog_index`, `stl_case_studies_index`, `stl_featured_customers_index`) holds the hero copy and lists the collection |
| `/blog/<slug>` | a `posts` entry (`entries/posts`), with the call to action from the blog page's own fields (`post_cta_*`); the CMS's own `/posts/<slug>` redirects there, and the sitemap lists `/blog/<slug>` |
| `/case-studies/<slug>`, `/featured-customers/<slug>` | `entries/<collection>` |
| `/academy`, `/academy/login`, `/academy/signup`, `/academy/<slug>` | the Astro site's static Academy design preview (`app/views/website/academy`, `StellaAcademyHelper`) |
| anything else | Tools › Redirects, then the CMS's `not-found` page, with a 404 and noindex |
| header, footer | the `nav`, `footer` and `general` globals |
| `/favicon.ico`, `/favicon.svg`, `/apple-touch-icon.png` | the theme's own files (`app/assets/images/stella`); pages link Settings › Branding's favicon |

## The content model

| Kind | What |
| --- | --- |
| Pages | every page, as blocks; `blog` also has fields of its own (the call to action on every post) |
| Collections with pages | `posts`, `case-studies`, `featured-customers` |
| Collections drawn where blocks show them (no pages, not in the sitemap) | `features` (the home cards and the features list pick them, `record_refs` by slug), `faqs` (grouped by their category select), `team`, `integrations`, `partners`, `pricing-tiers`, `testimonials` |
| Globals | `general` (name, phone, pricing line, share image), `nav`, `footer`, `scripts`, `academy_page` (the Academy preview's copy) |

Every list is in its entries' `order` field.

Every image is the media library's: an asset field (logos, icons, photos,
covers, a post's images, the share image, the Lily Pad screenshots, the team
photo), never a path typed as text. They're drawn with `stella_image_tag`
(`website_image_tag`'s resized copies, focal point and in-place Replace,
plus the original file); an image the design shows at its own width (a
post's) says so (`natural: true`). The header and footer logo and the
favicon are Settings › Branding's, with the theme's own as a fallback.

CMS values are copy, never markup, as on the Astro site: rich text is
flattened to plain text (`stella_str`, after its `src/lib/richtext.mjs`).
The demo, contact and other forms post to the Forms plugin
(`stella/forms.js`, after its `src/scripts/cms-forms.ts`), with Cloudflare
Turnstile when Settings › Forms has its keys.

The theme serves its own stylesheet, scripts and fonts at
`/_stella/<file>?v=<digest>` (`Stella::AssetsController`), rather than
through the asset pipeline, so it works on an install that hasn't compiled
a theme added from Settings › Plugins.

## Working on it

Clone it beside a Libre Publish checkout and link it in, with the live
site's content:

    bin/theme link ../stella-theme
    bin/pull <profile> --without-people      # then, in this copy only: Settings › General › How the site is served: Website
    bin/dev

Then:

    bin/rspec themes/stella/spec                          # every page, from the snapshot
    bundle exec herb lint themes/stella --fail-level warning
    bin/rails stella:snapshot                             # refresh the snapshot from this install (after bin/pull)

`spec/fixtures/cms/snapshot.json` is the CMS's content model and live
content. The spec draws every page and entry from it, and every block type
from its defaults, so a template reading a field the CMS doesn't declare
fails here before it breaks a page.

A change to the Astro site's design carries over the same way it was made:
the component's markup into its partial (with `data-c-<component>` on each
element), its CSS into `site.css` under the component's heading.

## Installing it

In the site's Libre Publish admin: Settings › Plugins › Add a plugin, and
give `GoLumin/stella-theme`. It installs the latest release and restarts;
the site is at `/` while the theme is switched on and the site is served as
Website (Settings › General). Publish a release here (bump
`lib/stella/version.rb`, tag `v0.1.0`, and a GitHub release) and the
theme's Update button takes it.

Proprietary. Copyright Lumin.
