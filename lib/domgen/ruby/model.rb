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

      def include_module(module_name)
        @included_modules << module_name
      end

      def classname
        @classname = parent.name unless @classname
        @classname
      end

      def fully_qualified_name
        "::#{parent.schema.ruby.module_name}::#{classname}"
      end

      def filename
        fqn = fully_qualified_name
        underscore(fqn[2..fqn.length])
      end
    end

    class RubyModule < RubyElement
      attr_writer :module_name

      def module_name
        @module_name = parent.name unless @module_name
        @module_name
      end
    end
  end

  class Attribute
    def ruby
      @ruby = Domgen::Ruby::RubyAttribute.new(self) unless @ruby
      @ruby
    end
  end

  class ObjectType
    def ruby
      @ruby = Domgen::Ruby::RubyClass.new(self) unless @ruby
      @ruby
    end
  end

  class Schema
    def ruby
      @ruby = Domgen::Ruby::RubyModule.new(self) unless @ruby
      @ruby
    end
  end
end
