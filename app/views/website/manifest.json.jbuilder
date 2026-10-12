# frozen_string_literal: true

# The site as an app on a home screen.
json.name stella_site[:name]
json.short_name stella_site[:name]
json.start_url "/"
json.display "standalone"
json.theme_color "#111318"
json.background_color "#111318"
json.icons [{src: "/apple-touch-icon.png", sizes: "180x180", type: "image/png"}]
