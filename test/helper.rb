$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'test/unit/assertions'
require 'domgen/core'
require 'domgen/mash'
require 'domgen/generators'
require 'domgen/facets/target_manager'
require 'domgen/facets/extension_manager'
require 'domgen/facets/faceted_model'
require 'domgen/facets/facet'
require 'domgen/facets/facet_container'
require 'domgen/facets/generators_integration'

module Domgen
  class Facets::ExtensionManager
    def unlock!
      @locked = false
    end
  end

  class TestCase < Minitest::Test
    include Domgen::Logging::Assertions

    module TestTemplateSetContainer
      class << self
        include Domgen::Generators::TemplateSetContainer

        attr_writer :helpers

        def derive_default_helpers(options)
          helpers
        end

        def helpers
          @helpers ||= []
        end

        def reset
          helpers.clear
          template_set_map.clear
          target_manager.reset_targets
        end
      end
    end

    module TestFacetContainer
      extend Domgen::Facets::FacetContainer

      class << self
        def reset
          @locked = false
          extension_manager.unlock!
          facet_map.clear
          target_manager.reset_targets
          if TestFacetContainer.const_defined?(:FacetDefinitions)
            TestFacetContainer::FacetDefinitions.constants.each do |constant|
              TestFacetContainer::FacetDefinitions.send(:remove_const, constant)
            end
          end
        end
      end
    end

    def setup
      TestTemplateSetContainer.reset
      TestFacetContainer.reset
      @temp_dir = nil
    end

    def teardown
      if passed?
        unless @temp_dir.nil?
          FileUtils.rm_rf @temp_dir unless ENV['NO_DELETE_DIR'] == 'true'
          @temp_dir = nil
        end
      else
        warn "Test #{self.class.name}.#{name} Failed. Leaving working directory #{@temp_dir}"
      end
    end

    def temp_dir
      if @temp_dir.nil?
        base_temp_dir = ENV['TEST_TMP_DIR'] || File.expand_path('tmp', __dir__)
        @temp_dir = "#{base_temp_dir}/tests/generators-#{Time.now.to_i}"
        FileUtils.mkdir_p @temp_dir
      end
      @temp_dir
    end

    def assert_raise(*args, &block)
      expected = args.first
      if expected.is_a?(Exception)
        exception = assert_raises(expected.class, &block)
        assert_equal expected.message, exception.message
        exception
      else
        assert_raises(*args, &block)
      end
    end

    def assert_raise_kind_of(expected_exception, &block)
      assert_raises(expected_exception, &block)
    end

    def assert_raise_message(expected_message, &block)
      exception = assert_raises(StandardError, &block)
      assert_equal expected_message, exception.message
      exception
    end

    def assert_true(value, message = nil)
      assert_equal true, value, message
    end

    def assert_generator_error(expected_message, &block)
      assert_logging_error(Domgen, expected_message) do
        yield block
      end
    end

    def assert_facet_error(expected_message, &block)
      assert_logging_error(Domgen, expected_message) do
        yield block
      end
    end
  end

  module Naming
    class << self
      def reset
        @pluralization_rules = nil
      end
    end

    class TestCase < Domgen::TestCase
      def setup
        super
        Domgen::Naming.reset
      end
    end
  end
end
