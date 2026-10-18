# frozen_string_literal: true

# Deterministic model provider for tests that records every generate call.
# With contents, it returns them in order and repeats the last one.
class FakeProvider
  attr_reader :calls

  def initialize(content: "{}", truncated: false, contents: [content])
    @contents = contents
    @truncated = truncated
    @calls = []
  end

  def generate(prompt:, schema:)
    content = @contents.fetch(@calls.size, @contents.last)
    @calls << { prompt:, schema: }
    JaExC::ProviderResponse.new(content: content, provider: :fake, model: "fake-model", truncated: @truncated)
  end
end
