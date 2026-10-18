# frozen_string_literal: true

# Deterministic reading analyzer for tests. Text without a configured reading returns nil.
class FakeAnalyzer
  def initialize(readings)
    @readings = readings
  end

  def reading(text)
    @readings[text]
  end
end
