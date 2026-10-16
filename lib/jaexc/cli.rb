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
    def initialize(out: $stdout, err: $stderr, provider: nil)
      @out = out
      @err = err
      @provider = provider
    end

    # @param argv [Array<String>] command-line arguments
    # @return [Integer] process exit status
    def run(argv)
      input = parse(argv)
      print_result(Creator.new(provider: @provider || env_provider).generate(**input))
      0
    rescue Error, OptionParser::ParseError, KeyError => e
      @err.puts("#{e.class}: #{e.message}")
      1
    end

    private

    def parse(argv)
      input = {}
      OptionParser.new("Usage: jaexc-demo [options]") do |opts|
        FLAGS.each { |flag, key, type, cast| opts.on(flag, type) { |value| input[key] = cast.call(value) } }
      end.parse!(argv.dup)
      input
    end

    def env_provider
      Providers::RubyLLM.new(provider: :ollama, model: ENV.fetch("JAEXC_LIVE_MODEL"),
                             base_url: ENV.fetch("JAEXC_BASE_URL", "http://localhost:11434/v1"),
                             timeout: Integer(ENV.fetch("JAEXC_TIMEOUT", "120")))
    end

    def print_result(result)
      @out.puts("#{result.provider} / #{result.model}: structurally validated, not teacher-reviewed")
      result.exercises.each.with_index(1) { |exercise, number| print_exercise(exercise, number) }
    end

    def print_exercise(exercise, number)
      @out.puts("", "#{number}. #{exercise.jp}", "   reading: #{exercise.reading}",
                "   target: #{exercise.target_kanji.join(" ")}")
      exercise.translations.each { |locale, text| @out.puts("   #{locale}: #{text}") }
    end
  end
end
