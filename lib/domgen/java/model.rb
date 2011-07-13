module Domgen
  module Java
    class JavaElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class JavaClass < JavaElement
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

      attr_writer :debug_attributes

      def debug_attributes
        @debug_attributes = object_type.attributes.collect { |a| a.name } unless @debug_attributes
        @debug_attributes
      end
    end

    class JavaField < JavaElement
      TYPE_MAP = {"string" => "java.lang.String",
                  "integer" => "java.lang.Integer",
                  "boolean" => "java.lang.Boolean",
                  "datetime" => "java.sql.Timestamp",
                  "text" => "java.lang.String",
                  "i_enum" => "java.lang.Integer",
                  "s_enum" => "java.lang.String",
                  "List" => "java.util.List"}

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

    class JavaPackage < JavaElement
      attr_writer :package

      def package
        @package || "#{data_module.repository.java.package}.#{data_module.name}"
      end

      def data_module
        self.parent
      end
    end

    class JavaModule < JavaElement
      attr_writer :package

      def package
        @package || repository.name
      end

      def repository
        self.parent
      end
    end
  end

  class Attribute
    self.extensions << :java

    def java
      @java = Domgen::Java::JavaField.new(self) unless @java
      @java
    end
  end

  class ObjectType
    self.extensions << :java

    def java
      @java = Domgen::Java::JavaClass.new(self) unless @java
      @java
    end
  end

  class DataModule
    self.extensions << :java

    def java
      @java = Domgen::Java::JavaPackage.new(self) unless @java
      @java
    end
  end

  class Repository
    self.extensions << :java

    def java
      @java = Domgen::Java::JavaModule.new(self) unless @java
      @java
    end
  end
end
