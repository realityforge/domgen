module Domgen
  module Generator
    class RenderContext
      def initialize
        @helpers = []
        @variables = {}
      end

      def add_helper(module_type)
        @helpers << module_type
      end

      def set_local_variable(key, value)
        @variables[key] = value
      end

      def context
        clazz = Class.new
        @helpers.each do |helper|
          clazz.send :include, helper
        end
        context = clazz.new
        @variables.each_pair do |k, v|
          context.instance_eval "def #{k}; @#{k}; end"
          context.instance_variable_set "@#{k}".to_sym, v
        end

        context
      end
    end
  end
end
