# frozen_string_literal: true

# Deterministic model provider for tests that records every generate call.
class FakeProvider
  Response = Data.define(:content, :provider, :model)

  attr_reader :calls

  def initialize(content: "{}")
    @content = content
    @calls = []
  end

  def generate(prompt:, schema:)
    @calls << { prompt:, schema: }
    Response.new(content: @content, provider: :fake, model: "fake-model")
  end
end
