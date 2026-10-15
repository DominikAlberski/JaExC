# frozen_string_literal: true

module JaExC
  # Defines which characters JaExC treats as supported kanji.
  #
  # The MVP supports only CJK Unified Ideographs (U+4E00..U+9FFF), which contain
  # every jōyō kanji. It rejects CJK Extension A and later extensions, and CJK
  # compatibility ideographs, because NFC normalization changes compatibility
  # ideographs to different code points.
  module Kanji
    RANGES = [0x4E00..0x9FFF].freeze

    # @param char [Object] candidate character
    # @return [Boolean] true when char is one character inside {RANGES}
    def self.supported?(char)
      char.is_a?(String) && char.length == 1 && RANGES.any? { |range| range.cover?(char.ord) }
    end
  end
end
