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
                  "text" => "java.lang.String",
                  "i_enum" => "java.lang.Integer",
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
            @java_type = parent.referenced_object.java.classname
          else
            @java_type = TYPE_MAP[parent.attribute_type.to_s]
          end
          raise "Unknown type #{parent.attribute_type}" unless @java_type
        end
        @java_type
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
