# frozen_string_literal: true

require "test_helper"

class TestCreator < Minitest::Test
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

  def setup
    @provider = FakeProvider.new
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

  def test_returns_provider_response
    response = @creator.generate(**valid_input)

    assert_equal "fake-model", response.model
  end
end
