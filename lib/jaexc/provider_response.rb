# frozen_string_literal: true

module JaExC
  # Raw model output with the identifiers of the provider and model that produced it.
  ProviderResponse = Data.define(:content, :provider, :model)
end
