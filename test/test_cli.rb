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

  def run_cli(argv, content: { exercises: [EXERCISE] }.to_json, analyzer: nil, contents: [content])
    @provider = FakeProvider.new(contents: contents)
    JaExC::CLI.new(out: @out, err: @err, provider: @provider, analyzer: analyzer).run(argv)
  end

  def with_env(name, value)
    previous = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    ENV[name] = previous
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

  def test_check_readings_prints_reading_differences
    assert_equal 0, run_cli(ARGV_OK + %w[--check-readings], analyzer: FakeAnalyzer.new("学校です。" => "ガッコウ"))
    assert_includes @out.string, "reading check (Sudachi): 1 difference(s); a difference is not proof of an error"
    assert_includes @out.string, "- 学校です。: model がっこうです。, analyzer ガッコウ"
  end

  def test_check_readings_prints_unreadable_text
    run_cli(ARGV_OK + %w[--check-readings], analyzer: FakeAnalyzer.new({}))

    assert_includes @out.string, "- 学校です。: model がっこうです。, analyzer cannot read"
  end

  def test_check_readings_prints_zero_differences
    run_cli(ARGV_OK + %w[--check-readings], analyzer: FakeAnalyzer.new("学校です。" => "ガッコウデス。"))

    assert_includes @out.string, "reading check (Sudachi): 0 difference(s)"
  end

  def test_without_flag_readings_are_not_checked
    run_cli(ARGV_OK, analyzer: FakeAnalyzer.new("学校です。" => "ガッコウ"))

    refute_includes @out.string, "reading check"
  end

  def test_check_readings_without_dictionary_env_fails_before_provider_call
    with_env("JAEXC_SUDACHI_DICT", nil) do
      assert_equal 1, run_cli(ARGV_OK + %w[--check-readings])
    end
    assert_match(/JAEXC_SUDACHI_DICT/, @err.string)
    assert_empty @provider.calls
  end

  def test_check_readings_with_missing_dictionary_fails_before_provider_call
    with_env("JAEXC_SUDACHI_DICT", "/no/such/system.dic") do
      assert_equal 1, run_cli(ARGV_OK + %w[--check-readings])
    end
    assert_includes @err.string, "JaExC::AnalyzerError: sudachi dictionary not found: /no/such/system.dic"
    assert_empty @provider.calls
  end

  def test_corrections_flag_lets_the_model_fix_rejected_exercises
    forbidden = { exercises: [EXERCISE.merge(jp: "駅の学校です。")] }.to_json

    assert_equal 0, run_cli(ARGV_OK + %w[--corrections 1], contents: [forbidden, { exercises: [EXERCISE] }.to_json])
    assert_includes @out.string, "fake / fake-model: 2 attempt(s), structurally validated, not teacher-reviewed"
  end

  def test_without_corrections_flag_rejected_exercises_fail
    forbidden = { exercises: [EXERCISE.merge(jp: "駅の学校です。")] }.to_json

    assert_equal 1, run_cli(ARGV_OK, contents: [forbidden, { exercises: [EXERCISE] }.to_json])
    assert_equal 1, @provider.calls.size
  end

  def test_unknown_flag_prints_usage_error
    assert_equal 1, run_cli(%w[--bogus])
    assert_match(/invalid option: --bogus/, @err.string)
  end
end
