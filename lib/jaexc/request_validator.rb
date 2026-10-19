# frozen_string_literal: true

module JaExC
  # Checks raw caller input against the request contract and collects every violation.
  class RequestValidator
    EXERCISE_TYPES = %i[kanji_reading kanji_words].freeze
    LEVELS = %i[N5 N4 N3 N2 N1].freeze
    COUNTS = (1..10)
    LOCALES = %i[en pl].freeze

    CHECKS = {
      exercise_type: :exercise_type_error,
      target_kanji: :target_kanji_error,
      allowed_kanji: :allowed_kanji_error,
      level: :level_error,
      count: :count_error,
      translation_locales: :translation_locales_error
    }.freeze
    OPTIONAL_KEYS = %i[allowed_kanji].freeze

    # @param input [Hash{Symbol => Object}] raw caller input
    # @return [Hash{Symbol => Object}] the same input when it is valid
    # @raise [InvalidRequestError] when the input breaks the request contract
    def self.call(input)
      new(input).call
    end

    def initialize(input)
      @input = input
    end

    def call
      errors = key_errors + value_errors
      raise InvalidRequestError, errors if errors.any?

      @input
    end

    private

    def key_errors
      missing = CHECKS.keys - OPTIONAL_KEYS - @input.keys
      unknown = @input.keys - CHECKS.keys
      errors = []
      errors << "missing keys: #{list(missing)}" if missing.any?
      errors << "unknown keys: #{list(unknown)}" if unknown.any?
      errors
    end

    def value_errors
      CHECKS.filter_map { |key, check| __send__(check) if @input.key?(key) }
    end

    def exercise_type_error
      return if EXERCISE_TYPES.include?(@input.fetch(:exercise_type))

      "exercise_type must be one of: #{list(EXERCISE_TYPES)}"
    end

    def target_kanji_error
      return "target_kanji must be a nonempty unique Array" unless unique_nonempty_array?(@input.fetch(:target_kanji))

      unsupported_kanji_error(:target_kanji)
    end

    def allowed_kanji_error
      return "allowed_kanji must be a unique Array" unless unique_array?(@input.fetch(:allowed_kanji))

      unsupported_kanji_error(:allowed_kanji)
    end

    def unsupported_kanji_error(key)
      unsupported = @input.fetch(key).reject { |char| Kanji.supported?(char) }
      "#{key} contains unsupported kanji: #{list(unsupported)}" if unsupported.any?
    end

    def level_error
      "level must be one of: #{list(LEVELS)}" unless LEVELS.include?(@input.fetch(:level))
    end

    def count_error
      count = @input.fetch(:count)
      return if count.instance_of?(Integer) && COUNTS.cover?(count)

      "count must be an Integer from #{COUNTS.first} to #{COUNTS.last}"
    end

    def translation_locales_error
      locales = @input.fetch(:translation_locales)
      return if unique_nonempty_array?(locales) && (locales - LOCALES).empty?

      "translation_locales must be a nonempty unique Array of: #{list(LOCALES)}"
    end

    def unique_nonempty_array?(value)
      unique_array?(value) && value.any?
    end

    def unique_array?(value)
      value.is_a?(Array) && value.uniq == value
    end

    def list(values)
      values.map(&:inspect).join(", ")
    end
  end
end
