# Libre Publish theme stella

A complete, plain theme for [Libre Publish](https://github.com/Martin-Business-Consultants/libre-publish):
a layout, pages, entries, a 404, every core block type, and design settings
(accent color, heading font, corners) an editor changes in Settings ›
Themes › Customize. ERB and CSS, no build.

Start a theme from it, in a Libre Publish checkout:

    bin/theme new acme            # clones this into ../acme-theme, renames it, links it in
    bin/pull production           # the live site's content, locally
    bin/dev                       # http://localhost:3000

Edit `app/views` and `app/assets/stylesheets/acme/site.css`; the site
reloads as you save. The whole story, from pulling a site to releasing the
theme, is in the CMS's docs: [Local development](https://martin-business-consultants.github.io/libre-publish/local-development.html).

## Releasing

Bump `lib/<theme>/version.rb`, tag `v<version>`, and publish a GitHub
release. Sites using the theme see the update in Settings › Themes.
