# frozen_string_literal: true

module JaExC
  # Checks parsed exercises against the kanji, target, reading, and duplicate rules of the request.
  # It reads kanji from the actual jp text, not from the declared target_kanji.
  class ExerciseValidator
    HAN = /[\p{Han}\p{Ideographic}]/
    ITERATION_MARK = "々"

    # @param exercises [Array<Exercise>] structurally valid exercises from {ResponseParser}
    # @param request [Request] validated caller input
    # @return [Array<Exercise>] the same exercises when every rule passes
    # @raise [InvalidExerciseError] when any exercise breaks a rule
    def self.call(exercises, request)
      new(exercises, request).call
    end

    def initialize(exercises, request)
      @exercises = exercises
      @request = request
    end

    def call
      errors = (exercise_errors + duplicate_errors).compact
      raise InvalidExerciseError.new(errors, exercises: @exercises) if errors.any?

      @exercises
    end

    private

    def exercise_errors
      @exercises.each_with_index.flat_map { |exercise, index| errors_for(exercise, "exercises[#{index}]") }
    end

    def errors_for(exercise, path)
      kanji = exercise.jp.scan(HAN).uniq - [ITERATION_MARK]
      [*character_errors(kanji, path), *target_errors(exercise.target_kanji, @request.target_kanji & kanji, path),
       reading_error(exercise.reading, path)]
    end

    def character_errors(kanji, path)
      supported, unsupported = kanji.partition { |char| Kanji.supported?(char) }
      [list_error(supported - @request.allowed_kanji, "#{path}.jp contains forbidden kanji"),
       list_error(unsupported, "#{path}.jp contains unsupported characters")]
    end

    def target_errors(declared, present, path)
      [("#{path}.jp contains no target kanji" if present.empty?),
       ("#{path}.target_kanji must list each target kanji in jp exactly once" unless declared.sort == present.sort)]
    end

    def reading_error(reading, path)
      "#{path}.reading must not contain kanji" if reading.match?(HAN)
    end

    def list_error(chars, prefix)
      "#{prefix}: #{chars.join(", ")}" unless chars.empty?
    end

    def duplicate_errors
      @exercises.each_with_index.map do |exercise, index|
        first = @exercises.index { |other| other.jp == exercise.jp }
        "exercises[#{index}].jp duplicates exercises[#{first}].jp" if first < index
      end
    end
  end
end
