# frozen_string_literal: true

module JaExC
  # Builds a prompt that asks the model to fix a rejected answer.
  # It repeats the original instructions, then the previous answer, then the broken rules.
  class CorrectionPrompt
    TEMPLATE = <<~TEXT
      %<original>s
      Your previous answer:
      %<content>s

      Your previous answer broke these rules:
      %<errors>s
      Return the same number of exercises again. Keep the exercises without problems. Fix only the listed problems.
    TEXT

    # @param original [Prompt] prompt of the first attempt
    # @param content [String] raw model output that broke the rules
    # @param errors [Array<String>] rule violations from {InvalidExerciseError#errors}
    # @return [Prompt] correction text with the original schema
    def self.call(original, content:, errors:)
      new(original, content, errors).call
    end

    def initialize(original, content, errors)
      @original = original
      @content = content
      @errors = errors
    end

    def call
      Prompt.new(text: format(TEMPLATE, original: @original.text, content: @content, errors: error_list),
                 schema: @original.schema)
    end

    private

    def error_list
      @errors.map { |error| "- #{error}" }.join("\n")
    end
  end
end
