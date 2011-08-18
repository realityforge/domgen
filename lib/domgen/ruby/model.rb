module Domgen
  module Ruby
    class RubyClass < Domgen.ParentedElement(:object_type)
      attr_writer :classname
      attr_reader :included_modules

      def include_module(module_name)
        (@included_modules ||= []) << module_name
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

    class RubyModule < Domgen.ParentedElement(:data_module)
      attr_writer :module_name

      def module_name
        @module_name || data_module.name
      end
    end
  end

  ObjectType.add_extension(:ruby, Domgen::Ruby::RubyClass)
  DataModule.add_extension(:ruby, Domgen::Ruby::RubyModule)
end
