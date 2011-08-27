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
  end
end
