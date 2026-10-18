# frozen_string_literal: true

require "optparse"
require "jaexc"

module JaExC
  # Command-line demo that runs one generation through the public {Creator} API.
  class CLI
    FLAGS = [
      ["--type TYPE", :exercise_type, String, :to_sym.to_proc],
      ["--target KANJI,...", :target_kanji, Array, :itself.to_proc],
      ["--allowed KANJI,...", :allowed_kanji, Array, :itself.to_proc],
      ["--level LEVEL", :level, String, :to_sym.to_proc],
      ["--count N", :count, Integer, :itself.to_proc],
      ["--locales LOCALE,...", :translation_locales, Array, ->(locales) { locales.map(&:to_sym) }]
    ].freeze

    # @param out [IO] destination for the generated exercises
    # @param err [IO] destination for error messages
    # @param provider [#generate, nil] model provider; nil builds an Ollama provider from the environment
    # @param analyzer [#reading, nil] reading analyzer for --check-readings; nil builds a Sudachi analyzer
    #   from JAEXC_SUDACHI_DICT
    def initialize(out: $stdout, err: $stderr, provider: nil, analyzer: nil)
      @out = out
      @err = err
      @provider = provider
      @analyzer = analyzer
    end

    # @param argv [Array<String>] command-line arguments
    # @return [Integer] process exit status
    def run(argv)
      input = parse(argv)
      print_result(creator.generate(**input))
      0
    rescue Error, OptionParser::ParseError, KeyError => e
      @err.puts("#{e.class}: #{e.message}")
      1
    end

    private

    def parse(argv)
      input = {}
      options(input).parse!(argv.dup)
      input
    end

    def options(input)
      OptionParser.new("Usage: jaexc-demo [options]") do |opts|
        FLAGS.each { |flag, key, type, cast| opts.on(flag, type) { |value| input[key] = cast.call(value) } }
        opts.on("--check-readings", "Compare readings with Sudachi (JAEXC_SUDACHI_DICT)") { @check_readings = true }
        opts.on("--corrections N", Integer, "Let the model fix rejected exercises N times") { |n| @corrections = n }
      end
    end

    def creator
      Creator.new(provider: @provider || env_provider, analyzer: (@analyzer || env_analyzer if @check_readings),
                  corrections: @corrections || 0)
    end

    def env_analyzer
      Analyzers::SudachiCli.new(dictionary: ENV.fetch("JAEXC_SUDACHI_DICT"))
    end

    def env_provider
      Providers::RubyLLM.new(provider: :ollama, model: ENV.fetch("JAEXC_LIVE_MODEL"),
                             base_url: ENV.fetch("JAEXC_BASE_URL", "http://localhost:11434/v1"),
                             timeout: Integer(ENV.fetch("JAEXC_TIMEOUT", "120")))
    end

    def print_result(result)
      @out.puts("#{result.provider} / #{result.model}: #{result.attempts} attempt(s), structurally validated, " \
                "not teacher-reviewed")
      result.exercises.each.with_index(1) { |exercise, number| print_exercise(exercise, number) }
      print_warnings(result.warnings) if @check_readings
    end

    def print_exercise(exercise, number)
      @out.puts("", "#{number}. #{exercise.jp}", "   reading: #{exercise.reading}",
                "   target: #{exercise.target_kanji.join(" ")}")
      exercise.translations.each { |locale, text| @out.puts("   #{locale}: #{text}") }
    end

    def print_warnings(warnings)
      @out.puts("", "reading check (Sudachi): #{warnings.size} difference(s); a difference is not proof of an error")
      warnings.each { |warning| @out.puts(warning_line(warning)) }
    end

    def warning_line(warning)
      "- #{warning.jp}: model #{warning.model_reading}, analyzer #{warning.analyzer_reading || "cannot read"}"
    end
  end
end
