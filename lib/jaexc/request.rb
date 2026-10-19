# frozen_string_literal: true

module JaExC
  # Validated, immutable caller input for one generation.
  #
  # The caller's +allowed_kanji+ is optional and lists the kanji allowed besides the targets.
  # {#allowed_kanji} holds the complete allowed set: the target kanji first, then the other allowed kanji,
  # without duplicates.
  Request = Data.define(:exercise_type, :target_kanji, :allowed_kanji, :level, :count, :translation_locales) do
    # Validates the input, then builds a Request that holds frozen copies of its Arrays.
    #
    # @param input [Hash{Symbol => Object}] raw caller input
    # @return [Request]
    # @raise [InvalidRequestError] when the input breaks the request contract
    def self.from(input)
      RequestValidator.call(input)
      allowed_kanji = (input.fetch(:target_kanji) | input.fetch(:allowed_kanji, [])).freeze
      new(**input.transform_values { |value| value.is_a?(Array) ? value.dup.freeze : value }, allowed_kanji:)
    end
  end
end
