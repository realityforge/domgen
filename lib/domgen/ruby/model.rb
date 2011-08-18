module Domgen
  module Ruby
    class RubyElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class RubyAttribute < RubyElement
    end

    class RubyClass < RubyElement
      attr_writer :classname
      attr_reader :included_modules

      def initialize(parent)
        super(parent)
        @included_modules = []
      end

      def object_type
        self.parent
      end

      def include_module(module_name)
        @included_modules << module_name
      end

      def classname
        @classname || object_type.name
      end

      def qualified_name
        "::#{object_type.data_module.ruby.module_name}::#{classname}"
      end

      def filename
        fqn = qualified_name
        underscore(fqn[2..fqn.length])
      end
    end

    class RubyModule < RubyElement
      attr_writer :module_name

      def module_name
        @module_name || data_module.name
      end

      def data_module
        self.parent
      end
    end
  end

  Attribute.add_extension(:ruby, Domgen::Ruby::RubyAttribute)
  ObjectType.add_extension(:ruby, Domgen::Ruby::RubyClass)
  DataModule.add_extension(:ruby, Domgen::Ruby::RubyModule)
end
