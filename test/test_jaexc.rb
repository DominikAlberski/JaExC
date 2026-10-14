# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class TestJaExC < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::JaExC::VERSION
  end

  def test_loads_without_rails
    lib = File.expand_path("../lib", __dir__)
    script = 'require "jaexc"; print defined?(Rails).inspect'
    output, status = Open3.capture2e(RbConfig.ruby, "-I", lib, "-e", script)

    assert status.success?, output
    assert_equal "nil", output
  end
end
