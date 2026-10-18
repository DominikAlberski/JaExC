# frozen_string_literal: true

module JaExC
  # Exercises that passed structural and character validation, with the provider and model that generated them.
  # A result does not mean the language or translations are teacher-approved.
  # Warnings are validation metadata, kept apart from the generated exercises.
  Result = Data.define(:exercises, :provider, :model, :warnings, :attempts) do
    # @param exercises [Array<Exercise>] validated exercises
    # @param provider [Symbol] provider identifier
    # @param model [String] model identifier
    # @param warnings [Array<ReadingWarning>] reading differences; empty when no analyzer checked the readings
    # @param attempts [Integer] provider calls needed: 1 for the first answer, plus 1 for each correction
    def initialize(exercises:, provider:, model:, warnings: [], attempts: 1) = super
  end
end
