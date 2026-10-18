# frozen_string_literal: true

# Deterministic model provider for tests that records every generate call.
class FakeProvider
  attr_reader :calls

  def initialize(content: "{}", truncated: false)
    @content = content
    @truncated = truncated
    @calls = []
  end

  def generate(prompt:, schema:)
    @calls << { prompt:, schema: }
    JaExC::ProviderResponse.new(content: @content, provider: :fake, model: "fake-model", truncated: @truncated)
  end
end
