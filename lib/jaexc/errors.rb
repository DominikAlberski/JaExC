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

  # Raised when the model provider fails, times out, or cannot be reached.
  class ProviderError < Error; end
end
