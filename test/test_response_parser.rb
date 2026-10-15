# frozen_string_literal: true

require "test_helper"
require "json"

class TestResponseParser < Minitest::Test
  FIELDS_ERROR = "must have exactly: jp, reading, translations, target_kanji"

  def request(count: 2)
    JaExC::Request.from(exercise_type: :kanji_reading, target_kanji: ["学"], allowed_kanji: %w[学 校],
                        level: :N5, count: count, translation_locales: %i[en pl])
  end

  def item(**overrides)
    { jp: "学校です。", reading: "がっこうです。", translations: { en: "It is a school.", pl: "To szkoła." },
      target_kanji: ["学"] }.merge(overrides)
  end

  def parse(document, count: 2)
    content = document.is_a?(String) ? document : document.to_json
    JaExC::ResponseParser.call(content, request(count: count))
  end

  def errors_for(document)
    assert_raises(JaExC::InvalidResponseError) { parse(document) }.errors
  end

  def assert_rejected(document, expected_error)
    assert_includes errors_for(document), expected_error
  end

  def test_returns_exercises
    exercise = JaExC::Exercise.new(jp: "学校です。", reading: "がっこうです。",
                                   translations: { en: "It is a school.", pl: "To szkoła." }, target_kanji: ["学"])

    assert_equal [exercise, exercise], parse({ exercises: [item, item] })
  end

  def test_freezes_exercise_values
    exercise = parse({ exercises: [item, item] }).first

    assert_predicate exercise.jp, :frozen?
    assert_predicate exercise.translations, :frozen?
    assert_predicate exercise.target_kanji, :frozen?
  end

  def test_rejects_invalid_json
    assert_rejected "{not json", "content is not valid JSON"
  end

  def test_rejects_fenced_json
    assert_rejected "```json\n#{{ exercises: [item, item] }.to_json}\n```", "content is not valid JSON"
  end

  def test_rejects_non_object_root
    assert_rejected [item, item], "root must be an object with only key: exercises"
  end

  def test_rejects_extra_root_key
    assert_rejected({ exercises: [item, item], note: "x" }, "root must be an object with only key: exercises")
  end

  def test_rejects_wrong_count
    assert_rejected({ exercises: [item] }, "exercises must be an Array of exactly 2 items")
  end

  def test_rejects_non_array_exercises
    assert_rejected({ exercises: "none" }, "exercises must be an Array of exactly 2 items")
  end

  def test_rejects_non_object_item
    assert_rejected({ exercises: [item, "x"] }, "exercises[1] #{FIELDS_ERROR}")
  end

  def test_rejects_missing_field
    assert_rejected({ exercises: [item.except(:reading), item] }, "exercises[0] #{FIELDS_ERROR}")
  end

  def test_rejects_extra_field
    assert_rejected({ exercises: [item(note: "x"), item] }, "exercises[0] #{FIELDS_ERROR}")
  end

  def test_rejects_blank_sentence
    assert_rejected({ exercises: [item(jp: " "), item] }, "exercises[0].jp must be a nonempty String")
  end

  def test_rejects_non_string_reading
    assert_rejected({ exercises: [item, item(reading: 1)] }, "exercises[1].reading must be a nonempty String")
  end

  def test_rejects_wrong_locales
    assert_rejected({ exercises: [item(translations: { en: "x" }), item] },
                    "exercises[0].translations must have exactly: en, pl")
  end

  def test_rejects_empty_translation
    assert_rejected({ exercises: [item(translations: { en: "x", pl: "" }), item] },
                    "exercises[0].translations.pl must be a nonempty String")
  end

  def test_rejects_non_string_targets
    assert_rejected({ exercises: [item(target_kanji: [1]), item] },
                    "exercises[0].target_kanji must be an Array of Strings")
  end

  def test_collects_errors_from_every_item
    errors = errors_for({ exercises: [item(jp: ""), item(reading: "")] })

    assert_equal ["exercises[0].jp must be a nonempty String", "exercises[1].reading must be a nonempty String"], errors
  end

  def test_error_keeps_content_out_of_message
    error = assert_raises(JaExC::InvalidResponseError) { parse("secret output") }

    assert_equal "secret output", error.content
    refute_includes error.message, "secret output"
  end
end
