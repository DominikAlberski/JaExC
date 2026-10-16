# frozen_string_literal: true

require "test_helper"

class TestRequestValidator < Minitest::Test
  cover "JaExC::RequestValidator*"

  TYPE_ERROR = "exercise_type must be one of: :kanji_reading, :kanji_words"

  def valid_input
    {
      exercise_type: :kanji_reading,
      target_kanji: ["学"],
      allowed_kanji: %w[学 校 日 本],
      level: :N5,
      count: 5,
      translation_locales: %i[en pl]
    }
  end

  def errors_for(input)
    error = assert_raises(JaExC::InvalidRequestError) { JaExC::RequestValidator.call(input) }
    error.errors
  end

  def assert_rejected(input, expected_error)
    assert_includes errors_for(input), expected_error
  end

  def test_accepts_valid_input
    assert_equal valid_input, JaExC::RequestValidator.call(valid_input)
  end

  def test_accepts_kanji_words
    input = valid_input.merge(exercise_type: :kanji_words)

    assert_equal input, JaExC::RequestValidator.call(input)
  end

  def test_rejects_unsupported_exercise_type
    assert_rejected valid_input.merge(exercise_type: :listening), TYPE_ERROR
  end

  def test_rejects_string_exercise_type
    assert_rejected valid_input.merge(exercise_type: "kanji_reading"), TYPE_ERROR
  end

  def test_rejects_missing_keys
    input = valid_input.except(:level, :count)

    assert_rejected input, "missing keys: :level, :count"
  end

  def test_reports_missing_target_kanji_only_once
    assert_equal ["missing keys: :target_kanji"], errors_for(valid_input.except(:target_kanji))
  end

  def test_reports_missing_value_only_as_missing_key
    assert_equal ["missing keys: :exercise_type"], errors_for(valid_input.except(:exercise_type))
  end

  def test_accepts_array_subclass
    input = valid_input.merge(translation_locales: Class.new(Array).new(%i[en]))

    assert_equal input, JaExC::RequestValidator.call(input)
  end

  def test_rejects_unknown_keys
    assert_rejected valid_input.merge(levl: :N5), "unknown keys: :levl"
  end

  def test_accepts_every_level
    %i[N5 N4 N3 N2 N1].each do |level|
      assert_equal level, JaExC::RequestValidator.call(valid_input.merge(level: level))[:level]
    end
  end

  def test_rejects_unsupported_level
    assert_rejected valid_input.merge(level: :N6), "level must be one of: :N5, :N4, :N3, :N2, :N1"
  end

  def test_rejects_string_level
    assert_rejected valid_input.merge(level: "N5"), "level must be one of: :N5, :N4, :N3, :N2, :N1"
  end

  def test_accepts_count_boundaries
    [1, 10].each do |count|
      assert_equal count, JaExC::RequestValidator.call(valid_input.merge(count: count))[:count]
    end
  end

  def test_rejects_count_outside_range
    [0, 11].each do |count|
      assert_rejected valid_input.merge(count: count), "count must be an Integer from 1 to 10"
    end
  end

  def test_rejects_non_integer_count
    ["5", 5.0, nil].each do |count|
      assert_rejected valid_input.merge(count: count), "count must be an Integer from 1 to 10"
    end
  end

  def test_accepts_single_locale
    input = valid_input.merge(translation_locales: [:pl])

    assert_equal input, JaExC::RequestValidator.call(input)
  end

  def test_rejects_invalid_translation_locales
    message = "translation_locales must be a nonempty unique Array of: :en, :pl"
    [[], %i[en en], [:de], ["en"], :en].each do |locales|
      assert_rejected valid_input.merge(translation_locales: locales), message
    end
  end

  def test_rejects_invalid_target_kanji_list
    message = "target_kanji must be a nonempty unique Array"
    [[], %w[学 学], "学", nil].each do |kanji|
      assert_rejected valid_input.merge(target_kanji: kanji), message
    end
  end

  def test_rejects_unsupported_target_kanji
    input = valid_input.merge(target_kanji: %w[学 あ 学校], allowed_kanji: %w[学 あ 学校])

    assert_rejected input, 'target_kanji contains unsupported kanji: "あ", "学校"'
  end

  def test_rejects_invalid_allowed_kanji_list
    message = "allowed_kanji must be a nonempty unique Array"
    [[], %w[学 学], "学", nil].each do |kanji|
      assert_rejected valid_input.merge(allowed_kanji: kanji), message
    end
  end

  def test_rejects_unsupported_allowed_kanji
    assert_rejected valid_input.merge(allowed_kanji: %w[学 々]), 'allowed_kanji contains unsupported kanji: "々"'
  end

  def test_rejects_allowed_kanji_without_every_target
    input = valid_input.merge(target_kanji: %w[学 校], allowed_kanji: %w[学 日])

    assert_rejected input, 'allowed_kanji must include every target_kanji, missing: "校"'
  end

  def test_skips_target_inclusion_check_when_target_list_is_invalid
    errors = errors_for(valid_input.merge(target_kanji: "学"))

    assert_equal ["target_kanji must be a nonempty unique Array"], errors
  end

  def test_collects_every_violation
    input = valid_input.merge(exercise_type: :listening, level: :N6, count: 0)

    assert_equal 3, errors_for(input).size
  end

  def test_error_message_lists_every_violation
    input = valid_input.merge(level: :N6, count: 0)
    error = assert_raises(JaExC::InvalidRequestError) { JaExC::RequestValidator.call(input) }

    assert_match(/level must be.*count must be/m, error.message)
  end
end
