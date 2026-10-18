# frozen_string_literal: true

require "test_helper"
require "tempfile"

class TestSudachiCli < Minitest::Test
  cover "JaExC::Analyzers::SudachiCli*"

  COMMAND = File.expand_path("support/bin/sudachi", __dir__)
  DICTIONARY = File.expand_path("support/fake_sudachi.dic", __dir__)

  def analyzer(dictionary: DICTIONARY, command: COMMAND)
    JaExC::Analyzers::SudachiCli.new(dictionary:, command:)
  end

  def test_reading_joins_token_readings_in_katakana
    assert_equal "チャヲノミマス", analyzer.reading("茶を飲みます")
  end

  def test_columns_are_split_on_tabs_only
    assert_equal "チャキゴウチャ", analyzer.reading("茶 茶")
  end

  def test_default_command_is_sudachi_on_path
    path = ENV.fetch("PATH")
    ENV["PATH"] = "#{File.dirname(COMMAND)}:#{path}"

    assert_equal "チャ", JaExC::Analyzers::SudachiCli.new(dictionary: DICTIONARY).reading("茶")
  ensure
    ENV["PATH"] = path
  end

  def test_unknown_kanji_gives_nil
    assert_nil analyzer.reading("㷔を見る")
  end

  def test_missing_dictionary_raises_on_construction
    error = assert_raises(JaExC::AnalyzerError) { analyzer(dictionary: "/no/such/system.dic") }

    assert_equal "sudachi dictionary not found: /no/such/system.dic", error.message
  end

  def test_missing_command_raises_on_construction
    error = assert_raises(JaExC::AnalyzerError) { analyzer(command: "jaexc-no-such-sudachi") }

    assert_match(/\Asudachi command cannot start: .*jaexc-no-such-sudachi/, error.message)
  end

  def test_broken_dictionary_raises_on_construction
    Tempfile.create("empty.dic") do |file|
      error = assert_raises(JaExC::AnalyzerError) { analyzer(dictionary: file.path) }

      assert_equal "sudachi failed with exit status 1: Failed to create dictionary: #{file.path}", error.message
    end
  end

  def test_command_failure_after_construction_raises
    error = assert_raises(JaExC::AnalyzerError) { analyzer.reading("壊") }

    assert_equal "sudachi failed with exit status 1: panicked at 壊", error.message
  end

  def test_probe_without_reading_raises_on_construction
    Tempfile.create("probe") do |file|
      File.write(file.path, "#!/bin/sh\ncat >/dev/null\necho EOS\n")
      File.chmod(0o755, file.path)
      error = assert_raises(JaExC::AnalyzerError) { analyzer(command: file.path) }

      assert_equal "sudachi cannot read the probe text 茶", error.message
    end
  end

  def test_analyzer_error_is_a_jaexc_error
    assert_operator JaExC::AnalyzerError, :<, JaExC::Error
  end
end
