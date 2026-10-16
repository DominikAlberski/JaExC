# frozen_string_literal: true

require "test_helper"

class TestRequest < Minitest::Test
  cover "JaExC::Request*"

  def valid_input
    {
      exercise_type: :kanji_reading,
      target_kanji: ["学"],
      allowed_kanji: %w[学 校 日 本],
      level: :N5,
      count: 5,
      translation_locales: %i[en pl]
    }
  end

  def test_from_builds_request_with_input_fields
    request = JaExC::Request.from(valid_input)

    assert_equal valid_input, request.to_h
  end

  def test_from_rejects_invalid_input
    assert_raises(JaExC::InvalidRequestError) { JaExC::Request.from(valid_input.merge(count: 0)) }
  end

  def test_from_freezes_arrays
    request = JaExC::Request.from(valid_input)

    assert_predicate request.target_kanji, :frozen?
    assert_predicate request.allowed_kanji, :frozen?
    assert_predicate request.translation_locales, :frozen?
  end

  def test_from_copies_arrays_so_caller_mutation_does_not_leak
    input = valid_input
    request = JaExC::Request.from(input)
    input[:allowed_kanji] << "火"

    assert_equal %w[学 校 日 本], request.allowed_kanji
  end
end
