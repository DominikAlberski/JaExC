# frozen_string_literal: true

require "test_helper"

class TestKanji < Minitest::Test
  def test_accepts_common_kanji
    %w[学 校 日 本 人].each { |char| assert JaExC::Kanji.supported?(char), char }
  end

  def test_accepts_range_boundaries
    assert JaExC::Kanji.supported?("一")
    assert JaExC::Kanji.supported?("鿿")
  end

  def test_rejects_characters_just_outside_the_range
    refute JaExC::Kanji.supported?("䷿")
    refute JaExC::Kanji.supported?("ꀀ")
  end

  def test_rejects_rare_and_compatibility_ideographs
    refute JaExC::Kanji.supported?("㐀"), "Extension A"
    refute JaExC::Kanji.supported?("\u{20000}"), "Extension B"
    refute JaExC::Kanji.supported?("豈"), "compatibility ideograph"
  end

  def test_rejects_kana_marks_punctuation_and_latin
    ["あ", "ア", "ｱ", "々", "〆", "。", "、", "a", "1", " "].each do |char|
      refute JaExC::Kanji.supported?(char), char.inspect
    end
  end

  def test_rejects_anything_but_a_single_character_string
    ["学校", "", "学︀", :学, nil, 1].each do |value|
      refute JaExC::Kanji.supported?(value), value.inspect
    end
  end
end
