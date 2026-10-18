# frozen_string_literal: true

module JaExC
  # Builds the instruction text and the request-specific JSON schema for a kanji-reading exercise.
  class PromptBuilder
    NONEMPTY_STRING = { type: "string", minLength: 1 }.freeze
    TEMPLATES = {
      kanji_reading: <<~TEXT,
        Write exactly %<count>s Japanese sentences for JLPT %<level>s kanji-reading practice.
        All sentences must be different.
        Each sentence must contain at least one target kanji: %<targets>s.
        Use only these kanji in each sentence: %<allowed>s.
        Do not put spaces in the Japanese text.
        If a word needs a kanji that is not allowed, write that part in kana, for example お茶 or 友だち.
        The reading must match the Japanese text exactly.
        Write all other words in kana. The repetition mark 々 is allowed.
        Give the reading of the full sentence in hiragana. Keep katakana words in katakana.
        Translate each sentence into these locales: %<locales>s.
        In target_kanji, list the target kanji that the sentence contains.
      TEXT
      kanji_words: <<~TEXT
        Write exactly %<count>s Japanese words for JLPT %<level>s kanji-reading practice.
        All words must be different real dictionary words.
        Each word must contain at least one target kanji: %<targets>s.
        Use only these kanji in each word: %<allowed>s.
        Do not put spaces in the Japanese text.
        If a word needs a kanji that is not allowed, write that part in kana, for example お茶 or 友だち.
        The reading must match the Japanese text exactly.
        A word may also contain hiragana and katakana. The repetition mark 々 is allowed.
        Give the reading of each word in hiragana. Keep katakana in katakana.
        Translate each word into these locales: %<locales>s.
        In target_kanji, list the target kanji that the word contains.
      TEXT
    }.freeze

    # @param request [Request] validated caller input
    # @return [Prompt]
    def self.call(request)
      new(request).call
    end

    def initialize(request)
      @request = request
    end

    def call
      Prompt.new(text: text, schema: schema)
    end

    private

    def text
      format(TEMPLATES.fetch(@request.exercise_type), **template_values)
    end

    def template_values
      { count: @request.count, level: @request.level, targets: list(@request.target_kanji),
        allowed: list(@request.allowed_kanji), locales: list(@request.translation_locales) }
    end

    def schema
      object_schema(exercises: exercises_schema)
    end

    def exercises_schema
      { type: "array", minItems: @request.count, maxItems: @request.count, items: exercise_schema }
    end

    def exercise_schema
      object_schema(jp: NONEMPTY_STRING, reading: NONEMPTY_STRING,
                    translations: translations_schema, target_kanji: targets_schema)
    end

    def translations_schema
      object_schema(@request.translation_locales.to_h { |locale| [locale, NONEMPTY_STRING] })
    end

    def targets_schema
      { type: "array", minItems: 1, uniqueItems: true, items: { type: "string", enum: @request.target_kanji } }
    end

    def object_schema(properties)
      { type: "object", properties: properties, required: properties.keys.map(&:to_s), additionalProperties: false }
    end

    def list(values)
      values.join(", ")
    end
  end
end
