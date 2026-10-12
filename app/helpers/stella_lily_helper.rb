# frozen_string_literal: true

# The Lily Pad Connect page's own vocabulary.
module StellaLilyHelper
  LILY_PAD_SHOTS = %w[.png .jpg .jpeg .webp .avif].freeze

  # A Step 1 screenshot named in the CMS ("step1-storage") as its address
  # under public/images/lily-pad, whatever its extension; nil when the file
  # isn't there (LilyPadQuoteTypes.astro's import.meta.glob check).
  def stella_lily_pad_shot(name)
    return if name.blank? || name.include?("/")

    ext = LILY_PAD_SHOTS.find { Stella::AssetsController.public_files.key?("images/lily-pad/#{name}#{it}") }
    "/images/lily-pad/#{name}#{ext}" if ext
  end
end
