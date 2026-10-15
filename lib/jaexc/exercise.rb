# frozen_string_literal: true

module JaExC
  # One generated exercise: Japanese text, its kana reading, translations by locale, and declared target kanji.
  Exercise = Data.define(:jp, :reading, :translations, :target_kanji)
end
