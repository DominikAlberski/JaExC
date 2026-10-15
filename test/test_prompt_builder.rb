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

  def test_text_permits_repetition_mark
    assert_includes build.text, "々"
  end
end
