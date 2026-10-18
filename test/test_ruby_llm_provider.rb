# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class TestRubyLLMProvider < Minitest::Test
  URL = "http://localhost:11434/v1/chat/completions"
  SCHEMA = { type: "object", properties: { a: { type: "string" } }, required: ["a"] }.freeze

  def setup
    @provider = JaExC::Providers::RubyLLM.new(provider: :ollama, model: "qwen3:8b",
                                              base_url: "http://localhost:11434/v1", timeout: 60)
  end

  def completion(content)
    { status: 200, headers: { "Content-Type" => "application/json" },
      body: { model: "qwen3:8b", choices: [{ index: 0, finish_reason: "stop",
                                             message: { role: "assistant", content: content } }] }.to_json }
  end

  def stub_success(content = '{"a":"b"}')
    stub_request(:post, URL).to_return(completion(content))
  end

  def generate(prompt = "hi")
    @provider.generate(prompt: prompt, schema: SCHEMA)
  end

  def sent_bodies
    WebMock::RequestRegistry.instance.requested_signatures.hash.keys.map { |request| JSON.parse(request.body) }
  end

  def test_returns_raw_content_with_identifiers
    stub_success

    assert_equal JaExC::ProviderResponse.new(content: '{"a":"b"}', provider: :ollama, model: "qwen3:8b"), generate
  end

  def test_sends_prompt_and_schema
    stub_success
    generate("make exercises")
    body = sent_bodies.first

    assert_equal [{ "role" => "user", "content" => "make exercises" }], body["messages"]
    assert_equal JSON.parse(SCHEMA.to_json), body.dig("response_format", "json_schema", "schema")
  end

  def test_disables_thinking_by_default
    stub_success
    generate

    assert_equal "none", sent_bodies.first["reasoning_effort"]
  end

  def test_thinking_option_keeps_the_model_default
    provider = JaExC::Providers::RubyLLM.new(provider: :ollama, model: "qwen3:8b",
                                             base_url: "http://localhost:11434/v1", timeout: 60, thinking: true)
    stub_success
    provider.generate(prompt: "hi", schema: SCHEMA)

    refute_includes sent_bodies.first.keys, "reasoning_effort"
  end

  def test_reports_truncated_output
    stub_request(:post, URL).to_return(completion("").merge(body: completion("").fetch(:body).sub("stop", "length")))

    assert_predicate generate, :truncated
  end

  def test_reports_complete_output_as_not_truncated
    stub_success

    refute_predicate generate, :truncated
  end

  def test_each_call_uses_a_fresh_chat
    stub_success
    generate("first")
    generate("second")

    assert_equal([1, 1], sent_bodies.map { |body| body["messages"].size })
  end

  def test_server_error_raises_provider_error_without_retry
    stub_request(:post, URL).to_return(status: 503, body: "{}")

    assert_raises(JaExC::ProviderError) { generate }
    assert_requested :post, URL, times: 1
  end

  def test_timeout_raises_provider_error_without_retry
    stub_request(:post, URL).to_timeout

    error = assert_raises(JaExC::ProviderError) { generate }
    assert_kind_of Faraday::Error, error.cause
    assert_requested :post, URL, times: 1
  end

  def test_refused_connection_raises_provider_error
    stub_request(:post, URL).to_raise(Errno::ECONNREFUSED)

    assert_raises(JaExC::ProviderError) { generate }
  end

  def test_does_not_change_global_configuration
    config = ::RubyLLM.config
    before = [config.ollama_api_base, config.max_retries, config.request_timeout, config.logger]
    stub_success
    generate

    assert_equal before, [config.ollama_api_base, config.max_retries, config.request_timeout, config.logger]
  end
end
