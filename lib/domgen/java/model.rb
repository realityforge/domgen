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

      def classname
        @classname = parent.name unless @classname
        @classname
      end

      def fully_qualified_name
        "#{parent.schema.java.package}.#{classname}"
      end

      attr_writer :debug_attributes

      def debug_attributes
        @debug_attributes = parent.attributes.collect{|a|a.name} unless @debug_attributes
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
      attr_writer :field_name

      def field_name
        @field_name = parent.name unless @field_name
        @field_name
      end

      attr_writer :java_type

      def java_type
        unless @java_type
          if :reference == parent.attribute_type
            @java_type = parent.referenced_object.java.fully_qualified_name
          elsif :i_enum == parent.attribute_type
            @java_type = "#{field_name}Value"
          elsif primitive?
            @java_type = primitive_java_type
          else
            @java_type = TYPE_MAP[parent.attribute_type.to_s] || parent.attribute_type.to_s
          end
        end
        @java_type
      end

      def non_primitive_java_type
        if :reference == parent.attribute_type
          return parent.referenced_object.java.fully_qualified_name
        elsif :i_enum == parent.attribute_type
          return "#{field_name}Value"
        else
          return TYPE_MAP[parent.attribute_type.to_s] || parent.attribute_type.to_s
        end
      end

      def primitive?
        (parent.attribute_type == :integer || parent.attribute_type == :boolean) && !parent.nullable? && !parent.generated_value?
      end

      def primitive_java_type
        return "int" if :integer == parent.attribute_type
        return "boolean" if :boolean == parent.attribute_type
        error("primitive_java_type invoked for non primitive method")
      end
    end

    class JavaPackage < JavaElement
      attr_writer :package

      def package
        @package = parent.name unless @package
        @package
      end
    end
  end

  class Attribute
    def java
      @java = Domgen::Java::JavaField.new(self) unless @java
      @java
    end
  end

  class ObjectType
    def java
      @java = Domgen::Java::JavaClass.new(self) unless @java
      @java
    end
  end

  class Schema
    def java
      @java = Domgen::Java::JavaPackage.new(self) unless @java
      @java
    end
  end
end
