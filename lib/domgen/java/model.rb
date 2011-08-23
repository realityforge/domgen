module Domgen
  module Java
    TYPE_MAP = {"string" => "java.lang.String",
                "integer" => "java.lang.Integer",
                "boolean" => "java.lang.Boolean",
                "datetime" => "java.sql.Timestamp",
                "text" => "java.lang.String",
                "i_enum" => "java.lang.Integer",
                "s_enum" => "java.lang.String",
                "List" => "java.util.List"}

    class JavaClass < Domgen.ParentedElement(:object_type)
      attr_writer :classname
      attr_accessor :label_attribute

      def classname
        @classname || object_type.name
      end

      def qualified_name
        "#{object_type.data_module.java.package}.#{self.classname}"
      end
    end

    class JavaEntity < JavaClass
      attr_writer :debug_attributes

      def debug_attributes
        @debug_attributes = object_type.attributes.collect { |a| a.name } unless @debug_attributes
        @debug_attributes
      end
    end

    class JavaField < Domgen.ParentedElement(:attribute)
      attr_writer :field_name

      def field_name
        @field_name || attribute.name
      end

      attr_writer :java_type

      def java_type
        return @java_type if @java_type
        return primitive_java_type if primitive?
        non_primitive_java_type
      end

      def non_primitive_java_type
        if :reference == attribute.attribute_type
          attribute.referenced_object.java.qualified_name
        elsif attribute.enum?
          return "#{attribute.object_type.java.qualified_name}.#{field_name}Value"
        else
          TYPE_MAP[attribute.attribute_type.to_s] || attribute.attribute_type.to_s
        end
      end

      def primitive?
        (attribute.attribute_type == :integer || attribute.attribute_type == :boolean) && !attribute.nullable? && !attribute.generated_value?
      end

      def primitive_java_type
        return "int" if :integer == attribute.attribute_type
        return "boolean" if :boolean == attribute.attribute_type
        error("primitive_java_type invoked for non primitive method")
      end
    end

    class JavaService < JavaClass
    end

    class JavaMethod < Domgen.ParentedElement(:service)
      def name
        Domgen::Naming.camelize(service.name.to_s)
      end
    end

    class JavaParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name.to_s)
      end

      attr_writer :java_type

      def java_type
        return @java_type if @java_type
        return primitive_java_type if primitive?
        non_primitive_java_type
      end

      def non_primitive_java_type
        TYPE_MAP[parameter.parameter_type.to_s] || parameter.parameter_type.to_s
      end

      def primitive?
        (parameter.parameter_type == :integer || parameter.parameter_type == :boolean) && !parameter.nullable?
      end

      def primitive_java_type
        return "int" if :integer == parameter.parameter_type
        return "boolean" if :boolean == parameter.parameter_type
        error("primitive_java_type invoked for non primitive parameter")
      end
    end

    class JavaMethodParameter < JavaParameter
    end

    class JavaMessageParameter < JavaParameter
    end

    class JavaReturn < Domgen.ParentedElement(:result)

      attr_writer :java_type

      def java_type
        return @java_type if @java_type
        return primitive_java_type if primitive?
        non_primitive_java_type
      end

      def non_primitive_java_type
        TYPE_MAP[result.return_type.to_s] || result.return_type.to_s
      end

      def primitive?
        (result.return_type == :integer || result.return_type == :boolean) && !result.nullable?
      end

      def primitive_java_type
        return "int" if :integer == result.return_type
        return "boolean" if :boolean == result.return_type
        error("primitive_java_type invoked for non primitive result")
      end
    end

    class JavaException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end
    end

    class JavaPackage < Domgen.ParentedElement(:data_module)
      attr_writer :package

      def package
        @package || "#{data_module.repository.java.package}.#{data_module.name}"
      end
    end

    class JavaModule < Domgen.ParentedElement(:repository)
      attr_writer :package

      def package
        @package || repository.name
      end
    end
  end

  FacetManager.define_facet(:java,
                            Attribute => Domgen::Java::JavaField,
                            ObjectType => Domgen::Java::JavaEntity,
                            MessageParameter => Domgen::Java::JavaMessageParameter,
                            Service => Domgen::Java::JavaService,
                            Method => Domgen::Java::JavaMethod,
                            Parameter => Domgen::Java::JavaMethodParameter,
                            Exception => Domgen::Java::JavaException,
                            Result => Domgen::Java::JavaReturn,
                            DataModule => Domgen::Java::JavaPackage,
                            Repository => Domgen::Java::JavaModule)
end
