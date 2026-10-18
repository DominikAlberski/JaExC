# frozen_string_literal: true

require "test_helper"

class TestReadingCheck < Minitest::Test
  cover "JaExC::ReadingCheck*"

  ANALYZER = FakeAnalyzer.new(
    "人は何を飲む" => "ヒトハナンヲノム",
    "茶を飲みます" => "チャヲノミマス",
    "友と食べます" => "トモトタベマス",
    "毎日食べます" => "マイニチタベマス",
    "学校です。" => "ガッコウデス。",
    "「はい」と言った。" => "「ハイ」トイッタ。",
    "コーヒーを飲む" => "コーヒーヲノム"
  )

  def exercise(text, reading)
    JaExC::Exercise.new(jp: text, reading:, translations: { en: "x" }, target_kanji: [])
  end

  def warnings_for(*exercises)
    JaExC::ReadingCheck.call(exercises, ANALYZER)
  end

  def test_wrong_model_readings_from_live_runs_give_warnings
    fixtures = [%w[人は何を飲む ひとはなにおをのむ], %w[茶を飲みます おちゃをのみます],
                %w[友と食べます ともだちとたべます], %w[毎日食べます まいにちはたべます]]

    assert_equal 4, warnings_for(*fixtures.map { |jp, reading| exercise(jp, reading) }).size
  end

  def test_warning_keeps_both_readings_as_received
    warning = JaExC::ReadingWarning.new(jp: "茶を飲みます", model_reading: "おちゃをのみます",
                                        analyzer_reading: "チャヲノミマス")

    assert_equal [warning], warnings_for(exercise("茶を飲みます", "おちゃをのみます"))
  end

  def test_hiragana_model_reading_matches_katakana_analyzer_reading
    assert_empty warnings_for(exercise("茶を飲みます", "ちゃをのみます"))
  end

  def test_katakana_model_reading_matches
    assert_empty warnings_for(exercise("茶を飲みます", "チャヲノミマス"))
  end

  def test_long_vowel_mark_is_kept_in_both_readings
    assert_empty warnings_for(exercise("コーヒーを飲む", "こーひーをのむ"))
  end

  def test_punctuation_is_ignored_in_both_readings
    assert_empty warnings_for(exercise("学校です。", "がっこうです"), exercise("「はい」と言った。", "はい、といった！"))
  end

  def test_unreadable_text_gives_warning_without_analyzer_reading
    warning = JaExC::ReadingWarning.new(jp: "㷔を見る", model_reading: "なにをみる", analyzer_reading: nil)

    assert_equal [warning], warnings_for(exercise("㷔を見る", "なにをみる"))
  end

  def test_only_mismatched_exercises_give_warnings_in_order
    warnings = warnings_for(exercise("茶を飲みます", "おちゃをのみます"), exercise("学校です。", "がっこうです。"),
                            exercise("友と食べます", "ともだちとたべます"))

    assert_equal %w[茶を飲みます 友と食べます], warnings.map(&:jp)
  end
end
