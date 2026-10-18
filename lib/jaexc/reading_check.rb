# frozen_string_literal: true

module JaExC
  # Compares each model reading with an analyzer reading of jp.
  # Katakana and hiragana compare as equal, and punctuation is ignored.
  class ReadingCheck
    PUNCTUATION = /\p{P}/
    KATAKANA = "ァ-ヶ"
    HIRAGANA = "ぁ-ゖ"

    # @param exercises [Array<Exercise>] validated exercises
    # @param analyzer [#reading] returns the kana reading of a text, or nil when it cannot read the text
    # @return [Array<ReadingWarning>] one warning for each exercise whose readings differ, in exercise order
    def self.call(exercises, analyzer)
      new(exercises, analyzer).call
    end

    def initialize(exercises, analyzer)
      @exercises = exercises
      @analyzer = analyzer
    end

    def call
      @exercises.filter_map { |exercise| warning(exercise, @analyzer.reading(exercise.jp)) }
    end

    private

    def warning(exercise, analyzer_reading)
      return if analyzer_reading && normalize(analyzer_reading) == normalize(exercise.reading)

      ReadingWarning.new(jp: exercise.jp, model_reading: exercise.reading, analyzer_reading:)
    end

    def normalize(reading)
      reading.gsub(PUNCTUATION, "").tr(KATAKANA, HIRAGANA)
    end
  end
end
