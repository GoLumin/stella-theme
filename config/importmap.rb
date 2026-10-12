# frozen_string_literal: true

# The website's scripts (Website.theme.importmap), apart from the admin's. The
# layout serves and imports them from the theme itself
# (StellaHelper#stella_javascript_tags).
pin_all_from Stella::Engine.root.join("app/javascript/stella"), under: "stella", to: "stella"
