# frozen_string_literal: true

module JaExC
  # Exercises that passed structural and character validation, with the provider and model that generated them.
  # A result does not mean the language or translations are teacher-approved.
  Result = Data.define(:exercises, :provider, :model)
end
