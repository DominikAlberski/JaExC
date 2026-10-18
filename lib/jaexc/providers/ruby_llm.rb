# frozen_string_literal: true

require "logger"
require "ruby_llm"

module JaExC
  module Providers
    # Model provider adapter over an isolated RubyLLM context with one attempt per call.
    class RubyLLM
      FAILURES = [::RubyLLM::Error, Faraday::Error].freeze

      # @param provider [Symbol] RubyLLM provider, for example :ollama
      # @param model [String] model identifier known to the provider
      # @param base_url [String] provider API base URL
      # @param timeout [Integer] request timeout in seconds
      # @param thinking [Boolean] true keeps the model thinking default; false disables thinking
      def initialize(provider:, model:, base_url:, timeout:, thinking: false)
        @provider = provider
        @model = model
        @thinking = thinking
        @context = ::RubyLLM.context { |config| configure(config, base_url, timeout) }
      end

      # @param prompt [String] instruction text
      # @param schema [Hash] JSON schema for structured output
      # @return [ProviderResponse]
      # @raise [ProviderError] when the provider call fails or times out
      def generate(prompt:, schema:)
        message = new_chat.with_schema(schema).ask(prompt)
        ProviderResponse.new(content: message.content, provider: @provider, model: @model,
                             truncated: message.finish_reason == :max_tokens)
      rescue *FAILURES => e
        raise ProviderError, "#{@provider} request failed: #{e.class}"
      end

      private

      def new_chat
        chat = @context.chat(model: @model, provider: @provider, assume_model_exists: true)
        @thinking ? chat : chat.with_thinking(effort: :none)
      end

      def configure(config, base_url, timeout)
        config.public_send(:"#{@provider}_api_base=", base_url)
        config.request_timeout = timeout
        config.max_retries = 0
        config.logger = Logger.new(IO::NULL)
      end
    end
  end
end
