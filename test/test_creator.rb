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

  def test_invalid_output_raises_invalid_response_error
    creator = JaExC::Creator.new(provider: FakeProvider.new(content: "{not json"))

    assert_raises(JaExC::InvalidResponseError) { creator.generate(**valid_input) }
  end

  def test_constraint_violation_raises_invalid_exercise_error
    content = { exercises: [EXERCISE.merge(jp: "駅の学校です。")] }.to_json
    creator = JaExC::Creator.new(provider: FakeProvider.new(content: content))

    assert_raises(JaExC::InvalidExerciseError) { creator.generate(**valid_input) }
  end
end
