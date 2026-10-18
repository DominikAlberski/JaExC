# frozen_string_literal: true

module JaExC
  # Exercises that passed structural and character validation, with the provider and model that generated them.
  # A result does not mean the language or translations are teacher-approved.
  # Warnings are validation metadata, kept apart from the generated exercises.
  Result = Data.define(:exercises, :provider, :model, :warnings) do
    # @param exercises [Array<Exercise>] validated exercises
    # @param provider [Symbol] provider identifier
    # @param model [String] model identifier
    # @param warnings [Array<ReadingWarning>] reading differences; empty when no analyzer checked the readings
    def initialize(exercises:, provider:, model:, warnings: []) = super
  end
end
