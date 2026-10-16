# frozen_string_literal: true

module JaExC
  # Base class for every error that JaExC raises.
  class Error < StandardError; end

  # Raised before any provider call when caller input breaks the request contract.
  class InvalidRequestError < Error
    # @return [Array<String>] frozen list of every contract violation
    attr_reader :errors

    # @param errors [Array<String>] contract violations
    def initialize(errors)
      @errors = errors.freeze
      super("invalid request: #{errors.join("; ")}")
    end
  end

  # Raised when model output is not valid JSON or breaks the expected structure.
  # The message lists the violations and never contains the raw output.
  class InvalidResponseError < Error
    # @return [Array<String>] frozen list of every structure violation
    attr_reader :errors

    # @return [String] raw model output, kept out of the message so logs do not contain it
    attr_reader :content

    # @param errors [Array<String>] structure violations
    # @param content [String] raw model output
    def initialize(errors, content:)
      @errors = errors.freeze
      @content = content
      super("invalid response: #{errors.join("; ")}")
    end
  end

  # Raised when parsed exercises break the kanji, target, reading, or duplicate rules of the request.
  class InvalidExerciseError < Error
    # @return [Array<String>] frozen list of every constraint violation
    attr_reader :errors

    # @return [Array<Exercise>] frozen list of the rejected exercises
    attr_reader :exercises

    # @param errors [Array<String>] constraint violations
    # @param exercises [Array<Exercise>] rejected exercises
    def initialize(errors, exercises:)
      @errors = errors.freeze
      @exercises = exercises.dup.freeze
      super("invalid exercises: #{errors.join("; ")}")
    end
  end

  # Raised when the model provider fails, times out, or cannot be reached.
  class ProviderError < Error; end
end
