# frozen_string_literal: true

require "test_helper"

class TestExerciseValidator < Minitest::Test
  DECLARATION_ERROR = "target_kanji must list each target kanji in jp exactly once"

  def request
    JaExC::Request.from(exercise_type: :kanji_reading, target_kanji: %w[学 本], allowed_kanji: %w[学 校 日 本],
                        level: :N5, count: 2, translation_locales: %i[en])
  end

  def exercise(**overrides)
    JaExC::Exercise.new(jp: "学校です。", reading: "がっこうです。", translations: { en: "It is a school." },
                        target_kanji: ["学"], **overrides)
  end

  def validate(*exercises)
    JaExC::ExerciseValidator.call(exercises, request)
  end

  def errors_for(*exercises)
    assert_raises(JaExC::InvalidExerciseError) { validate(*exercises) }.errors
  end

  def assert_rejected(changed, expected_error)
    assert_includes errors_for(exercise(jp: "本です。", target_kanji: ["本"]), changed), expected_error
  end

  def test_returns_valid_exercises
    exercises = [exercise, exercise(jp: "日本の学校です。", target_kanji: %w[本 学])]

    assert_equal exercises, validate(*exercises)
  end

  def test_rejects_kanji_outside_allowed_set
    assert_rejected exercise(jp: "学校の駅と駅前です。"), "exercises[1].jp contains forbidden kanji: 駅, 前"
  end

  def test_rejects_unsupported_han_characters
    jp = "学校\u{FA30}\u{3400}\u{2F08}〆〇です。"

    assert_rejected exercise(jp:), "exercises[1].jp contains unsupported characters: \u{FA30}, \u{3400}, \u{2F08}, 〆, 〇"
  end

  def test_permits_iteration_mark_in_jp
    exercises = [exercise, exercise(jp: "日々学校です。")]

    assert_equal exercises, validate(*exercises)
  end

  def test_requires_a_target_kanji_in_jp
    assert_rejected exercise(jp: "日です。", target_kanji: []), "exercises[1].jp contains no target kanji"
  end

  def test_rejects_undeclared_target
    assert_rejected exercise(jp: "日本の学校です。"), "exercises[1].#{DECLARATION_ERROR}"
  end

  def test_rejects_declared_target_missing_from_jp
    assert_rejected exercise(target_kanji: %w[学 本]), "exercises[1].#{DECLARATION_ERROR}"
  end

  def test_rejects_declared_kanji_that_is_not_a_target
    assert_rejected exercise(target_kanji: %w[学 校]), "exercises[1].#{DECLARATION_ERROR}"
  end

  def test_rejects_repeated_declaration
    assert_rejected exercise(target_kanji: %w[学 学]), "exercises[1].#{DECLARATION_ERROR}"
  end

  def test_rejects_kanji_in_reading
    assert_rejected exercise(reading: "学こうです。"), "exercises[1].reading must not contain kanji"
  end

  def test_rejects_iteration_mark_in_reading
    assert_rejected exercise(reading: "がっこう々"), "exercises[1].reading must not contain kanji"
  end

  def test_rejects_duplicate_jp
    errors = errors_for(exercise, exercise)

    assert_equal ["exercises[1].jp duplicates exercises[0].jp"], errors
  end

  def test_collects_errors_from_every_exercise
    errors = errors_for(exercise(jp: "駅です。", target_kanji: []), exercise(reading: "学"))

    assert_equal ["exercises[0].jp contains forbidden kanji: 駅", "exercises[0].jp contains no target kanji",
                  "exercises[1].reading must not contain kanji"], errors
  end

  def test_error_exposes_rejected_exercises
    exercises = [exercise, exercise]
    error = assert_raises(JaExC::InvalidExerciseError) { validate(*exercises) }

    assert_equal exercises, error.exercises
    assert_predicate error.exercises, :frozen?
    assert_equal "invalid exercises: exercises[1].jp duplicates exercises[0].jp", error.message
  end
end
