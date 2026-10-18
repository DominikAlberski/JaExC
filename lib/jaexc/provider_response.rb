# frozen_string_literal: true

module JaExC
  # Raw model output with the identifiers of the provider and model that produced it.
  # Truncated output stopped at the token limit before the model finished it.
  ProviderResponse = Data.define(:content, :provider, :model, :truncated) do
    # @param content [String] raw model output
    # @param provider [Symbol] provider identifier
    # @param model [String] model identifier
    # @param truncated [Boolean] true when the output stopped at the token limit
    def initialize(content:, provider:, model:, truncated: false) = super
  end
end
