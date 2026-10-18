# frozen_string_literal: true

module JaExC
  # A model reading that differs from the analyzer reading of the same jp text.
  # A nil analyzer_reading means the analyzer could not read jp, so the model reading is not verified.
  # A warning does not prove an error: the analyzer can select another correct reading.
  ReadingWarning = Data.define(:jp, :model_reading, :analyzer_reading)
end
