# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "jaexc"

require "minitest/autorun" unless defined?(Mutant)
require "mutant/minitest/coverage"

require_relative "support/fake_provider"
require_relative "support/fake_analyzer"
