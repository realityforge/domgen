module Domgen
  module Ruby
    class RubyAttribute < Domgen.ParentedElement(:attribute)
      attr_writer :validate

      def validate?
        @validate.nil? ? true : @validate
      end
    end

    class RubyClass < Domgen.ParentedElement(:entity)
      attr_writer :classname

      def included_modules
        @included_modules || []
      end

      def include_module(module_name)
        (@included_modules ||= []) << module_name
      end

      def classname
        @classname || entity.name
      end

      def qualified_name
        "::#{entity.data_module.ruby.module_name}::#{classname}"
      end

      def filename
        fqn = qualified_name.gsub(/::/, '/')
        Domgen::Naming.underscore(fqn[1..fqn.length])
      end
    end

    class RubyModule < Domgen.ParentedElement(:data_module)
      attr_writer :module_name

      def module_name
        @module_name || data_module.name
      end
    end
  end

  FacetManager.define_facet(:ruby,
                            Entity => Domgen::Ruby::RubyClass,
                            Attribute => Domgen::Ruby::RubyAttribute,
                            DataModule => Domgen::Ruby::RubyModule )
end
