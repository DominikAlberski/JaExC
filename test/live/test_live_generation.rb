# frozen_string_literal: true

require "test_helper"

class TestLiveGeneration < Minitest::Test
  def setup
    skip "set JAEXC_LIVE_MODEL to run against a local Ollama model" unless ENV["JAEXC_LIVE_MODEL"]
    WebMock.allow_net_connect! if defined?(WebMock)
  end

  def teardown
    WebMock.disable_net_connect! if defined?(WebMock)
  end

  def test_generates_valid_exercises_with_local_model
    result = creator.generate(exercise_type: :kanji_reading, target_kanji: ["学"], allowed_kanji: %w[学 校 日 本 生],
                              level: :N5, count: 2, translation_locales: %i[en pl])

    assert_equal 2, result.exercises.size
    assert_equal ENV.fetch("JAEXC_LIVE_MODEL"), result.model
  end

  private

  def creator
    JaExC::Creator.new(provider: JaExC::Providers::RubyLLM.new(
      provider: :ollama, model: ENV.fetch("JAEXC_LIVE_MODEL"),
      base_url: ENV.fetch("JAEXC_BASE_URL", "http://localhost:11434/v1"), timeout: 300
    ))
  end
end
