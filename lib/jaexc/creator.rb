# frozen_string_literal: true

module JaExC
  # Public entry point that generates exercises through a provider.
  class Creator
    # @param provider [#generate] model provider adapter
    # @param analyzer [#reading, nil] optional reading analyzer; without it, readings are not checked
    # @param corrections [Integer] how many times the model may fix exercises that break a rule
    def initialize(provider:, analyzer: nil, corrections: 0)
      @provider = provider
      @analyzer = analyzer
      @corrections = corrections
    end

    # @param input [Hash{Symbol => Object}] request fields, see {Request}
    # @return [Result] with reading warnings when an analyzer is configured
    # @raise [InvalidRequestError] before any provider call when the input is invalid
    # @raise [ProviderError] when the provider call fails
    # @raise [InvalidResponseError] when the model output breaks the expected structure
    # @raise [InvalidExerciseError] when the exercises of the last attempt break the kanji, target, reading,
    #   or duplicate rules
    def generate(**input)
      request = Request.from(input)
      prompt = PromptBuilder.call(request)
      attempt(request, prompt, prompt, 1)
    end

    private

    def attempt(request, original, prompt, number)
      response = @provider.generate(prompt: prompt.text, schema: prompt.schema)
      result(exercises(response, request), response, number)
    rescue InvalidExerciseError => e
      raise if number > @corrections

      attempt(request, original, correction(original, response, e), number + 1)
    end

    def correction(original, response, error)
      CorrectionPrompt.call(original, content: response.content, errors: error.errors)
    end

    def exercises(response, request)
      parsed = ResponseParser.call(response.content, request, truncated: response.truncated)
      ExerciseValidator.call(parsed, request)
    end

    def result(exercises, response, attempts)
      Result.new(exercises:, provider: response.provider, model: response.model, warnings: warnings(exercises),
                 attempts:)
    end

    def warnings(exercises)
      @analyzer ? ReadingCheck.call(exercises, @analyzer) : []
    end
  end
end
