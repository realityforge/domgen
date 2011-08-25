module Domgen
  module Java
    DEFAULT_ENTITY_PACKAGE_SUFFIX = "entity"
    DEFAULT_SERVICE_PACKAGE_SUFFIX = "service"

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
    end

    class JavaEntity < JavaClass
      attr_writer :debug_attributes

      def debug_attributes
        @debug_attributes || object_type.attributes.collect { |a| a.name }
      end

      def qualified_name
        "#{object_type.data_module.java.entity_package}.#{self.classname}"
      end
    end

    module JavaCharacteristic
      attr_writer :java_type

      def java_type
        return @java_type if @java_type
        return primitive_java_type if primitive?
        non_primitive_java_type
      end

      def non_primitive_java_type
        if :reference == characteristic.characteristic_type
          object_type_to_classname(characteristic.referenced_object)
        elsif characteristic.enum?
          return "#{object_type_to_classname(characteristic.object_type)}.#{characteristic.name}Value"
        else
          Domgen::Java::TYPE_MAP[characteristic.characteristic_type.to_s] || characteristic.characteristic_type.to_s
        end
      end

      def primitive?
        (characteristic.characteristic_type == :integer || characteristic.characteristic_type == :boolean) && !characteristic.nullable? && (!characteristic.respond_to?(:generated_value?) || !characteristic.generated_value?)
      end

      def primitive_java_type
        return "int" if :integer == characteristic.characteristic_type
        return "boolean" if :boolean == characteristic.characteristic_type
        error("primitive_java_type invoked for non primitive method")
      end

      protected

      def characteristic
        raise "characteristic unimplemented"
      end

      def object_type_to_classname(object_type)
        raise "object_type_to_classname unimplemented"
      end
    end

    class JavaField < Domgen.ParentedElement(:attribute)
      attr_writer :field_name

      def field_name
        @field_name || attribute.name
      end

      include JavaCharacteristic

      protected

      def characteristic
        attribute
      end

      def object_type_to_classname(object_type)
        object_type.java.qualified_name
      end
    end

    class JavaService < JavaClass
      def qualified_name
        "#{object_type.data_module.java.service_package}.#{self.classname}"
      end
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

      include JavaCharacteristic

      protected

      def characteristic
        parameter
      end

      def object_type_to_classname(object_type)
        object_type.java.qualified_name
      end
    end

    class JavaMethodParameter < JavaParameter
    end

    class JavaMessageParameter < JavaParameter
    end

    class JavaReturn < Domgen.ParentedElement(:result)

      include JavaCharacteristic

      protected

      def characteristic
        result
      end

      def object_type_to_classname(object_type)
        object_type.java.qualified_name
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
        @package || "#{data_module.repository.java.package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      def package_defined?
        !@package.nil?
      end

      attr_writer :entity_package

      def entity_package
        return @entity_package if @entity_package
        return "#{package}.#{DEFAULT_ENTITY_PACKAGE_SUFFIX}" if package_defined?
        "#{data_module.repository.java.entity_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      attr_writer :service_package

      def service_package
        return @service_package if @service_package
        return "#{package}.#{DEFAULT_SERVICE_PACKAGE_SUFFIX}" if package_defined?
        "#{data_module.repository.java.service_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end
    end

    class JavaModule < Domgen.ParentedElement(:repository)
      attr_writer :package

      def package
        @package || Domgen::Naming.underscore(repository.name)
      end

      attr_writer :entity_package

      def entity_package
        @entity_package || "#{package}.#{DEFAULT_ENTITY_PACKAGE_SUFFIX}"
      end

      attr_writer :service_package

      def service_package
        @service_package || "#{package}.#{DEFAULT_SERVICE_PACKAGE_SUFFIX}"
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
