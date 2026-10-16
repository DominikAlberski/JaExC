# frozen_string_literal: true

require "test_helper"
require "jaexc/cli"
require "stringio"

class TestCLI < Minitest::Test
  EXERCISE = { jp: "学校です。", reading: "がっこうです。", translations: { en: "It is a school.", pl: "To szkoła." },
               target_kanji: ["学"] }.freeze
  ARGV_OK = %w[--type kanji_reading --target 学 --allowed 学,校,日,本 --level N5 --count 1 --locales en,pl].freeze

  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  def run_cli(argv, content: { exercises: [EXERCISE] }.to_json)
    @provider = FakeProvider.new(content: content)
    JaExC::CLI.new(out: @out, err: @err, provider: @provider).run(argv)
  end

  def test_sends_parsed_flags_as_request
    run_cli(ARGV_OK)
    prompt = JaExC::PromptBuilder.call(JaExC::Request.from(exercise_type: :kanji_reading, target_kanji: ["学"],
                                                           allowed_kanji: %w[学 校 日 本], level: :N5, count: 1,
                                                           translation_locales: %i[en pl]))

    assert_equal [{ prompt: prompt.text, schema: prompt.schema }], @provider.calls
  end

  def test_prints_exercises_and_metadata
    assert_equal 0, run_cli(ARGV_OK)
    assert_includes @out.string, "fake / fake-model"
    assert_includes @out.string, "1. 学校です。"
    assert_includes @out.string, "reading: がっこうです。"
    assert_includes @out.string, "target: 学"
    assert_includes @out.string, "pl: To szkoła."
  end

  def test_prints_library_error_and_returns_failure
    assert_equal 1, run_cli(ARGV_OK, content: "{not json")
    assert_match(/JaExC::InvalidResponseError: invalid response/, @err.string)
    assert_empty @out.string
  end

  def test_invalid_request_makes_no_provider_call
    assert_equal 1, run_cli(ARGV_OK + %w[--count 0])
    assert_match(/InvalidRequestError/, @err.string)
    assert_empty @provider.calls
  end

  def test_missing_flag_is_reported_as_invalid_request
    assert_equal 1, run_cli(%w[--type kanji_reading])
    assert_match(/missing/, @err.string)
  end

  def test_unknown_flag_prints_usage_error
    assert_equal 1, run_cli(%w[--bogus])
    assert_match(/invalid option: --bogus/, @err.string)
  end
end
