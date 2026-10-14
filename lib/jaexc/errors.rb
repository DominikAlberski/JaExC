# frozen_string_literal: true

module JaExC
  class Error < StandardError; end

  # Raised before any provider call when caller input breaks the request contract.
  class InvalidRequestError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors.freeze
      super("invalid request: #{errors.join("; ")}")
    end
  end
end
