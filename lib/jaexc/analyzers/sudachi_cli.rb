# frozen_string_literal: true

require "open3"

module JaExC
  module Analyzers
    # Reads Japanese text with the Sudachi command and a Sudachi system dictionary.
    # The reading is the written form in katakana, so the particle は reads as ハ.
    class SudachiCli
      PROBE = "茶"
      READING_COLUMN = 4
      HAN = /[\p{Han}\p{Ideographic}]/

      # @param dictionary [String] path to a Sudachi system dictionary, for example system_core.dic
      # @param command [String] name or path of the Sudachi executable
      # @raise [AnalyzerError] when the dictionary or command is missing, or the probe text cannot be read
      def initialize(dictionary:, command: "sudachi")
        @dictionary = dictionary
        @command = command
        raise AnalyzerError, "sudachi dictionary not found: #{dictionary}" unless File.file?(dictionary)
        raise AnalyzerError, "sudachi cannot read the probe text #{PROBE}" unless reading(PROBE)
      end

      # @param text [String] one line of Japanese text
      # @return [String, nil] katakana reading, or nil when the dictionary does not know a word in text
      # @raise [AnalyzerError] when the command cannot start or fails
      def reading(text)
        joined = analyze(text).lines.map { |line| line.split("\t").at(READING_COLUMN) }.join
        joined unless joined.empty? || joined.match?(HAN)
      end

      private

      def analyze(text)
        output, error, status = Open3.capture3(@command, "-a", "-l", @dictionary, stdin_data: "#{text}\n")
        raise AnalyzerError, failure(status, error) unless status.success?

        output
      rescue SystemCallError => e
        raise AnalyzerError, "sudachi command cannot start: #{e}"
      end

      def failure(status, error)
        "sudachi failed with exit status #{status.exitstatus}: #{error.strip}"
      end
    end
  end
end
