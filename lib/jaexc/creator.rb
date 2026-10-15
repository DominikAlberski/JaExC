# frozen_string_literal: true

module JaExC
  # Public entry point that generates exercises through a provider.
  class Creator
    # @param provider [#generate] model provider adapter
    def initialize(provider:)
      @provider = provider
    end

    # @param input [Hash{Symbol => Object}] request fields, see {Request}
    # @return [Array<Exercise>]
    # @raise [InvalidRequestError] before any provider call when the input is invalid
    # @raise [ProviderError] when the provider call fails
    # @raise [InvalidResponseError] when the model output breaks the expected structure
    def generate(**input)
      request = Request.from(input)
      prompt = PromptBuilder.call(request)
      response = @provider.generate(prompt: prompt.text, schema: prompt.schema)
      ResponseParser.call(response.content, request)
    end
  end
end
