# frozen_string_literal: true

require "test_helper"

class TestPromptBuilder < Minitest::Test
  def request(**overrides)
    JaExC::Request.from(
      {
        exercise_type: :kanji_reading,
        target_kanji: %w[学 校],
        allowed_kanji: %w[学 校 日 本],
        level: :N5,
        count: 5,
        translation_locales: %i[en pl]
      }.merge(overrides)
    )
  end

  def build(**overrides)
    JaExC::PromptBuilder.call(request(**overrides))
  end

  def exercises_schema(**overrides)
    build(**overrides).schema[:properties][:exercises]
  end

  def exercise_schema(**overrides)
    exercises_schema(**overrides)[:items]
  end

  def test_returns_prompt
    assert_instance_of JaExC::Prompt, build
  end

  def test_schema_root_requires_only_exercises
    schema = build.schema

    assert_equal "object", schema[:type]
    assert_equal ["exercises"], schema[:required]
    refute schema[:additionalProperties]
  end

  def test_schema_fixes_exercise_count
    schema = exercises_schema(count: 3)

    assert_equal [3, 3], [schema[:minItems], schema[:maxItems]]
  end

  def test_schema_requires_every_exercise_field
    schema = exercise_schema

    assert_equal %w[jp reading translations target_kanji], schema[:required]
    refute schema[:additionalProperties]
  end

  def test_schema_requires_nonempty_sentence_and_reading
    properties = exercise_schema[:properties]

    assert_equal({ type: "string", minLength: 1 }, properties[:jp])
    assert_equal({ type: "string", minLength: 1 }, properties[:reading])
  end

  def test_schema_requires_only_requested_locales
    translations = exercise_schema(translation_locales: [:pl])[:properties][:translations]

    assert_equal ["pl"], translations[:required]
    assert_equal [:pl], translations[:properties].keys
    refute translations[:additionalProperties]
  end

  def test_schema_limits_declared_targets_to_requested_targets
    targets = exercise_schema[:properties][:target_kanji]

    assert_equal %w[学 校], targets[:items][:enum]
    assert_equal 1, targets[:minItems]
    assert targets[:uniqueItems]
  end

  def test_text_states_request_values
    text = build.text

    ["N5", "exactly 5", "学, 校", "学, 校, 日, 本", "en, pl"].each { |value| assert_includes text, value }
  end

  def test_reading_text_asks_for_sentences
    assert_includes build.text, "exactly 5 Japanese sentences"
  end

  def test_words_text_asks_for_words
    assert_includes build(exercise_type: :kanji_words).text, "exactly 5 Japanese words"
  end

  def test_words_text_states_request_values
    text = build(exercise_type: :kanji_words).text

    ["N5", "学, 校", "学, 校, 日, 本", "en, pl", "々"].each { |value| assert_includes text, value }
  end

  def test_reading_text_asks_for_distinct_sentences
    assert_includes build.text, "different"
  end

  def test_words_text_asks_for_distinct_words
    assert_includes build(exercise_type: :kanji_words).text, "different"
  end

  def test_words_schema_matches_reading_schema
    assert_equal build.schema, build(exercise_type: :kanji_words).schema
  end

  def test_reading_text_forbids_spaces
    assert_includes build.text, "Do not put spaces in the Japanese text."
  end

  def test_words_text_forbids_spaces
    assert_includes build(exercise_type: :kanji_words).text, "Do not put spaces in the Japanese text."
  end

  KANA_FALLBACK = "If a word needs a kanji that is not allowed, write that part in kana, for example お茶 or 友だち."
  EXACT_READING = "The reading must match the Japanese text exactly."

  def test_reading_text_asks_for_kana_fallback_and_exact_reading
    [KANA_FALLBACK, EXACT_READING].each { |line| assert_includes build.text, line }
  end

  def test_words_text_asks_for_kana_fallback_and_exact_reading
    [KANA_FALLBACK, EXACT_READING].each { |line| assert_includes build(exercise_type: :kanji_words).text, line }
  end

  def test_reading_text_asks_for_kana_in_all_other_words
    assert_includes build.text, "Write all other words in kana."
    refute_includes build.text, "every other word"
  end

  def test_text_permits_repetition_mark
    assert_includes build.text, "々"
  end

  def test_reading_text_asks_for_even_target_use
    assert_includes build.text, "Use the target kanji evenly: each target kanji should appear in about the same " \
                                "number of sentences."
  end

  def test_words_text_asks_for_even_target_use
    assert_includes build(exercise_type: :kanji_words).text,
                    "Use the target kanji evenly: each target kanji should appear in about the same number of words."
  end

  def test_reading_text_asks_for_allowed_kanji_check
    assert_includes build.text, "Before you answer, check every kanji in each sentence against the allowed list."
  end

  def test_words_text_asks_for_allowed_kanji_check
    assert_includes build(exercise_type: :kanji_words).text,
                    "Before you answer, check every kanji in each word against the allowed list."
  end
end
