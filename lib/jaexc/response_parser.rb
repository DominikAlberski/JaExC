# frozen_string_literal: true

require "json"

module JaExC
  # Parses raw model output into exercises and checks its structure against the request.
  class ResponseParser
    FIELDS = %w[jp reading translations target_kanji].freeze

    # @param content [String] raw model output
    # @param request [Request] validated caller input
    # @param truncated [Boolean] true when the provider stopped the output at the token limit
    # @return [Array<Exercise>]
    # @raise [InvalidResponseError] when the output is truncated, is not valid JSON,
    #   or breaks the expected structure
    def self.call(content, request, truncated: false)
      new(content, request, truncated).call
    end

    def initialize(content, request, truncated)
      @content = content
      @request = request
      @truncated = truncated
    end

    def call
      errors = document_errors
      raise InvalidResponseError.new(errors, content: @content) if errors.any?

      items.map { |item| build(item) }
    end

    private

    def document_errors
      return ["content is truncated: the model reached its token limit"] if @truncated
      return ["content is not valid JSON"] unless parse
      return ["root must be an object with only key: exercises"] unless root?
      return ["exercises must be an Array of exactly #{@request.count} items"] unless items?

      items.each_with_index.flat_map { |item, index| item_errors(item, "exercises[#{index}]") }
    end

    def parse
      @document = JSON.parse(@content, freeze: true)
      true
    rescue JSON::ParserError, TypeError
      false
    end

    def root?
      @document.is_a?(Hash) && @document.keys == ["exercises"]
    end

    def items?
      items.is_a?(Array) && items.size == @request.count
    end

    def items
      @document["exercises"]
    end

    def item_errors(item, path)
      return ["#{path} must have exactly: #{FIELDS.join(", ")}"] unless exact_keys?(item, FIELDS)

      [text_error(item["jp"], "#{path}.jp"), text_error(item["reading"], "#{path}.reading"),
       *translations_errors(item["translations"], "#{path}.translations"),
       targets_error(item["target_kanji"], "#{path}.target_kanji")].compact
    end

    def translations_errors(value, path)
      return ["#{path} must have exactly: #{locales.join(", ")}"] unless exact_keys?(value, locales)

      value.filter_map { |locale, text| text_error(text, "#{path}.#{locale}") }
    end

    def text_error(value, path)
      "#{path} must be a nonempty String" unless value.is_a?(String) && !value.strip.empty?
    end

    def targets_error(value, path)
      "#{path} must be an Array of Strings" unless value.is_a?(Array) && value.all?(String)
    end

    def exact_keys?(value, keys)
      value.is_a?(Hash) && value.keys.sort == keys.sort
    end

    def locales
      @request.translation_locales.map(&:to_s)
    end

    def build(item)
      Exercise.new(jp: item["jp"], reading: item["reading"], target_kanji: item["target_kanji"],
                   translations: item["translations"].transform_keys(&:to_sym).freeze)
    end
  end
end
