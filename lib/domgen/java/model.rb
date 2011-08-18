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

    class JavaClass < BaseParentedElement
      attr_writer :classname
      attr_accessor :label_attribute

      def object_type
        self.parent
      end

      def classname
        @classname || object_type.name
      end

      def qualified_name
        "#{object_type.data_module.java.package}.#{self.classname}"
      end
    end

    class JavaEntity < JavaClass
      def object_type
        self.parent
      end

      attr_writer :debug_attributes

      def debug_attributes
        @debug_attributes = object_type.attributes.collect { |a| a.name } unless @debug_attributes
        @debug_attributes
      end
    end

    class JavaField < BaseParentedElement
      def attribute
        self.parent
      end

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
      def service
        self.parent
      end
    end

    class JavaMethod < BaseParentedElement
      def service
        self.parent
      end

      def name
        Domgen::Naming.camelize(service.name.to_s)
      end
    end

    class JavaParameter < BaseParentedElement
      def parameter
        self.parent
      end

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

    class JavaReturn < BaseParentedElement
      def result
        self.parent
      end

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

    class JavaException < BaseParentedElement
      def exception
        self.parent
      end

      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end
    end

    class JavaPackage < BaseParentedElement
      attr_writer :package

      def package
        @package || "#{data_module.repository.java.package}.#{data_module.name}"
      end

      def data_module
        self.parent
      end
    end

    class JavaModule < BaseParentedElement
      attr_writer :package

      def package
        @package || repository.name
      end

      def repository
        self.parent
      end
    end
  end

  Attribute.add_extension(:java, Domgen::Java::JavaField)
  ObjectType.add_extension(:java, Domgen::Java::JavaEntity)
  Service.add_extension(:java, Domgen::Java::JavaService)
  Method.add_extension(:java, Domgen::Java::JavaMethod)
  Parameter.add_extension(:java, Domgen::Java::JavaParameter)
  Exception.add_extension(:java, Domgen::Java::JavaException)
  Result.add_extension(:java, Domgen::Java::JavaReturn)
  DataModule.add_extension(:java, Domgen::Java::JavaPackage)
  Repository.add_extension(:java, Domgen::Java::JavaModule)
end
