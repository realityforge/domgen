module Domgen
  module Java
    TYPE_MAP = {"integer" => "java.lang.Integer",
                "boolean" => "java.lang.Boolean",
                "datetime" => "java.sql.Timestamp",
                "text" => "java.lang.String"}

    module JavaCharacteristic
      attr_writer :java_type

      def java_type
        return @java_type if @java_type
        return primitive_java_type if primitive?
        non_primitive_java_type
      end

      def non_primitive_java_type
        if :reference == characteristic.characteristic_type
          entity_to_classname(characteristic.referenced_entity)
        elsif characteristic.enum?
          return enumeration_to_classname(characteristic.enumeration)
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

      def entity_to_classname(entity)
        raise "entity_to_classname unimplemented"
      end

      def enumeration_to_classname(enumeration)
        raise "enumeration_to_classname unimplemented"
      end
    end
  end
end
