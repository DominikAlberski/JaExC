# frozen_string_literal: true

module JaExC
  # Public entry point that generates exercises through a provider.
  class Creator
    # @param provider [#generate] model provider adapter
    def initialize(provider:)
      @provider = provider
    end

    # @param input [Hash{Symbol => Object}] request fields, see {Request}
    # @return [Object] the raw provider response
    # @raise [InvalidRequestError] before any provider call when the input is invalid
    def generate(**input)
      prompt = PromptBuilder.call(Request.from(input))
      @provider.generate(prompt: prompt.text, schema: prompt.schema)
    end
  end
end
