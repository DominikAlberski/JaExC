# frozen_string_literal: true

module JaExC
  # Public entry point that generates exercises through a provider.
  class Creator
    # @param provider [#generate] model provider adapter
    # @param analyzer [#reading, nil] optional reading analyzer; without it, readings are not checked
    def initialize(provider:, analyzer: nil)
      @provider = provider
      @analyzer = analyzer
    end

    # @param input [Hash{Symbol => Object}] request fields, see {Request}
    # @return [Result] with reading warnings when an analyzer is configured
    # @raise [InvalidRequestError] before any provider call when the input is invalid
    # @raise [ProviderError] when the provider call fails
    # @raise [InvalidResponseError] when the model output breaks the expected structure
    # @raise [InvalidExerciseError] when the exercises break the kanji, target, reading, or duplicate rules
    def generate(**input)
      request = Request.from(input)
      prompt = PromptBuilder.call(request)
      response = @provider.generate(prompt: prompt.text, schema: prompt.schema)
      result(exercises(response, request), response)
    end

    private

    def exercises(response, request)
      parsed = ResponseParser.call(response.content, request, truncated: response.truncated)
      ExerciseValidator.call(parsed, request)
    end

    def result(exercises, response)
      Result.new(exercises:, provider: response.provider, model: response.model, warnings: warnings(exercises))
    end

    def warnings(exercises)
      @analyzer ? ReadingCheck.call(exercises, @analyzer) : []
    end
  end
end
