# frozen_string_literal: true

require "test_helper"

class TestCorrectionPrompt < Minitest::Test
  cover "JaExC::CorrectionPrompt*"

  ORIGINAL = JaExC::Prompt.new(text: "Write exactly 2 Japanese sentences.\n", schema: { type: "object" })
  CONTENT = '{"exercises":[{"jp":"ご飯を食べます。"}]}'
  ERRORS = ["exercises[0].jp contains forbidden kanji: 飯", "exercises[1].jp contains forbidden kanji: 達"].freeze

  def correction
    JaExC::CorrectionPrompt.call(ORIGINAL, content: CONTENT, errors: ERRORS)
  end

  def test_keeps_the_original_schema
    assert_same ORIGINAL.schema, correction.schema
  end

  def test_text_is_original_instructions_previous_answer_and_errors_in_order
    expected = <<~TEXT
      Write exactly 2 Japanese sentences.

      Your previous answer:
      #{CONTENT}

      Your previous answer broke these rules:
      - exercises[0].jp contains forbidden kanji: 飯
      - exercises[1].jp contains forbidden kanji: 達
      Return the same number of exercises again. Keep the exercises without problems. Fix only the listed problems.
    TEXT

    assert_equal expected, correction.text
  end
end
