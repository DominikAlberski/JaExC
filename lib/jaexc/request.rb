# frozen_string_literal: true

module JaExC
  # Validated, immutable caller input for one generation.
  Request = Data.define(:exercise_type, :target_kanji, :allowed_kanji, :level, :count, :translation_locales) do
    # Validates the input, then builds a Request that holds frozen copies of its Arrays.
    #
    # @param input [Hash{Symbol => Object}] raw caller input
    # @return [Request]
    # @raise [InvalidRequestError] when the input breaks the request contract
    def self.from(input)
      RequestValidator.call(input)
      new(**input.transform_values { |value| value.is_a?(Array) ? value.dup.freeze : value })
    end
  end
end
