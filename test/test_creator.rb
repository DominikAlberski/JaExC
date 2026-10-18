# frozen_string_literal: true

require "test_helper"

class TestCreator < Minitest::Test
  EXERCISE = { jp: "学校です。", reading: "がっこうです。", translations: { en: "It is a school.", pl: "To szkoła." },
               target_kanji: ["学"] }.freeze

  def valid_input
    {
      exercise_type: :kanji_reading,
      target_kanji: ["学"],
      allowed_kanji: %w[学 校 日 本],
      level: :N5,
      count: 1,
      translation_locales: %i[en pl]
    }
  end

  def setup
    @provider = FakeProvider.new(content: { exercises: [EXERCISE] }.to_json)
    @creator = JaExC::Creator.new(provider: @provider)
  end

  def test_invalid_input_raises_without_provider_call
    assert_raises(JaExC::InvalidRequestError) { @creator.generate(**valid_input, count: 0) }
    assert_empty @provider.calls
  end

  def test_valid_input_calls_provider_once
    @creator.generate(**valid_input)

    assert_equal 1, @provider.calls.size
  end

  def test_sends_built_prompt_to_provider
    @creator.generate(**valid_input)
    prompt = JaExC::PromptBuilder.call(JaExC::Request.from(valid_input))

    assert_equal [{ prompt: prompt.text, schema: prompt.schema }], @provider.calls
  end

  def test_returns_result_with_exercises_and_model_metadata
    result = @creator.generate(**valid_input)

    assert_equal JaExC::Result.new(exercises: [JaExC::Exercise.new(**EXERCISE)], provider: :fake, model: "fake-model"),
                 result
  end

  def test_result_has_no_warnings_without_analyzer
    assert_empty @creator.generate(**valid_input).warnings
  end

  def test_analyzer_reading_mismatch_adds_warning_to_result
    creator = JaExC::Creator.new(provider: @provider, analyzer: FakeAnalyzer.new("学校です。" => "ガッコウ"))
    warning = JaExC::ReadingWarning.new(jp: "学校です。", model_reading: "がっこうです。", analyzer_reading: "ガッコウ")

    assert_equal [warning], creator.generate(**valid_input).warnings
  end

  def test_analyzer_reading_match_adds_no_warning
    creator = JaExC::Creator.new(provider: @provider, analyzer: FakeAnalyzer.new("学校です。" => "ガッコウデス。"))

    assert_empty creator.generate(**valid_input).warnings
  end

  FORBIDDEN = { exercises: [EXERCISE.merge(jp: "駅の学校です。")] }.to_json
  VALID = { exercises: [EXERCISE] }.to_json

  def correcting_creator(contents, corrections:)
    @provider = FakeProvider.new(contents: contents)
    JaExC::Creator.new(provider: @provider, corrections: corrections)
  end

  def test_first_valid_answer_takes_one_attempt
    assert_equal 1, @creator.generate(**valid_input).attempts
  end

  def test_correction_returns_result_of_corrected_answer
    result = correcting_creator([FORBIDDEN, VALID], corrections: 1).generate(**valid_input)

    assert_equal [JaExC::Exercise.new(**EXERCISE)], result.exercises
    assert_equal 2, result.attempts
  end

  def test_correction_sends_correction_prompt_built_from_original_prompt
    correcting_creator([FORBIDDEN, FORBIDDEN, VALID], corrections: 2).generate(**valid_input)
    original = JaExC::PromptBuilder.call(JaExC::Request.from(valid_input))
    correction = JaExC::CorrectionPrompt.call(original, content: FORBIDDEN,
                                                        errors: ["exercises[0].jp contains forbidden kanji: 駅"])

    assert_equal([original.text, correction.text, correction.text], @provider.calls.map { |call| call[:prompt] })
  end

  def test_last_error_is_raised_when_corrections_run_out
    creator = correcting_creator([FORBIDDEN], corrections: 2)

    assert_raises(JaExC::InvalidExerciseError) { creator.generate(**valid_input) }
    assert_equal 3, @provider.calls.size
  end

  def test_without_corrections_invalid_exercises_take_one_call
    creator = correcting_creator([FORBIDDEN, VALID], corrections: 0)

    assert_raises(JaExC::InvalidExerciseError) { creator.generate(**valid_input) }
    assert_equal 1, @provider.calls.size
  end

  def test_corrections_default_to_zero
    @provider = FakeProvider.new(contents: [FORBIDDEN, VALID])

    assert_raises(JaExC::InvalidExerciseError) { JaExC::Creator.new(provider: @provider).generate(**valid_input) }
    assert_equal 1, @provider.calls.size
  end

  def test_invalid_response_is_not_corrected
    creator = correcting_creator(["{not json", VALID], corrections: 2)

    assert_raises(JaExC::InvalidResponseError) { creator.generate(**valid_input) }
    assert_equal 1, @provider.calls.size
  end

  def test_invalid_output_raises_invalid_response_error
    creator = JaExC::Creator.new(provider: FakeProvider.new(content: "{not json"))

    assert_raises(JaExC::InvalidResponseError) { creator.generate(**valid_input) }
  end

  def test_truncated_output_raises_invalid_response_error
    creator = JaExC::Creator.new(provider: FakeProvider.new(content: "", truncated: true))
    error = assert_raises(JaExC::InvalidResponseError) { creator.generate(**valid_input) }

    assert_equal ["content is truncated: the model reached its token limit"], error.errors
  end

  def test_constraint_violation_raises_invalid_exercise_error
    content = { exercises: [EXERCISE.merge(jp: "駅の学校です。")] }.to_json
    creator = JaExC::Creator.new(provider: FakeProvider.new(content: content))

    assert_raises(JaExC::InvalidExerciseError) { creator.generate(**valid_input) }
  end
end
