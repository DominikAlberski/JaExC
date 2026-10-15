# frozen_string_literal: true

module JaExC
  # Instruction text and JSON output schema for one provider call.
  Prompt = Data.define(:text, :schema)
end
