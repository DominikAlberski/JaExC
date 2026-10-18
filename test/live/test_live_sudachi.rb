# frozen_string_literal: true

require "test_helper"

class TestLiveSudachi < Minitest::Test
  def setup
    skip "set JAEXC_SUDACHI_DICT to run against a local Sudachi dictionary" unless ENV["JAEXC_SUDACHI_DICT"]
  end

  def analyzer
    JaExC::Analyzers::SudachiCli.new(dictionary: ENV.fetch("JAEXC_SUDACHI_DICT"))
  end

  def test_reads_written_form_of_particles
    assert_equal "トウキョウヘイキマス", analyzer.reading("東京へ行きます")
  end

  def test_unknown_kanji_gives_nil
    assert_nil analyzer.reading("㷔を見る")
  end

  def test_wrong_model_readings_from_live_runs_give_warnings
    exercises = [%w[茶を飲みます おちゃをのみます], %w[友と食べます ともだちとたべます], %w[毎日食べます まいにちはたべます]]
                .map { |jp, reading| JaExC::Exercise.new(jp:, reading:, translations: {}, target_kanji: []) }

    assert_equal 3, JaExC::ReadingCheck.call(exercises, analyzer).size
  end
end
