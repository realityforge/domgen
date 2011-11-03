module Domgen
  module Java
    TYPE_MAP = {"integer" => "java.lang.Integer",
                "boolean" => "java.lang.Boolean",
                "datetime" => "java.sql.Timestamp",
                "text" => "java.lang.String"}

    module JavaCharacteristic
      attr_writer :java_type

      def java_type(modality = :default)
        return @java_type if @java_type
        return primitive_java_type if primitive?(modality)
        non_primitive_java_type(modality)
      end

      def non_primitive_java_type(modality = :default)
        if characteristic.reference?
          entity_to_classname(characteristic.referenced_entity)
        elsif characteristic.enum?
          return enumeration_to_classname(characteristic.enumeration)
        else
          Domgen::Java::TYPE_MAP[characteristic.characteristic_type.to_s] || characteristic.characteristic_type.to_s
        end
      end

      def primitive?(modality = :default)
        return false if characteristic.nullable?
        return false if (characteristic.respond_to?(:generated_value?) && characteristic.generated_value?)
        return true if characteristic.integer? || characteristic.boolean?

        if :default == modality
          return false
        elsif :transport == modality
          return false unless attribute.reference?
          return characteristic.referenced_entity.primary_key.integer? || characteristic.referenced_entity.primary_key.boolean?
        else
          error("unknown modality #{modality}")
        end
      end

      def primitive_java_type
        return "int" if characteristic.integer?
        return "boolean" if characteristic.boolean?
        error("primitive_java_type invoked for non primitive method")
      end

      protected

      def entity_to_classname(entity)
        entity.send(facet_key).qualified_name
      end

      def enumeration_to_classname(enumeration)
        enumeration.send(facet_key).qualified_name
      end

      def characteristic
        raise "characteristic unimplemented"
      end

      def facet_key
        raise "facet_key unimplemented"
      end
    end

    module EEJavaCharacteristic
      include JavaCharacteristic

      protected

      def facet_key
        :jpa
      end
    end

    module ImitJavaCharacteristic
      include JavaCharacteristic

      protected

      def facet_key
        :imit
      end
    end
  end
end
