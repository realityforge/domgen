module Domgen
  module Java
    TYPE_MAP = {"integer" => "java.lang.Integer",
                "boolean" => "java.lang.Boolean",
                "datetime" => "java.util.Date",
                "date" => "java.util.Date",
                "text" => "java.lang.String",
                "void" => "java.lang.Void" }

    module JavaCharacteristic
      def name(modality = :default)
        if :default == modality
          return characteristic.name
        elsif :transport == modality
          return characteristic.referencing_link_name if characteristic.reference?
          return characteristic.name
        else
          error("unknown modality #{modality}")
        end
      end

      attr_writer :java_type

      def java_type(modality = :default)
        return @java_type if @java_type
        return "void" if :void == characteristic.characteristic_type
        return primitive_java_type(modality) if primitive?(modality)
        non_primitive_java_type(modality)
      end

      def non_primitive_java_type(modality = :default)
        if characteristic.reference?
          if :default == modality
            return characteristic.referenced_entity.send(facet_key).qualified_name
          elsif :transport == modality
            return characteristic.referenced_entity.primary_key.send(facet_key).non_primitive_java_type(modality)
          else
            error("unknown modality #{modality}")
          end
        elsif characteristic.enumeration?
          if :default == modality
            return characteristic.enumeration.send(facet_key).qualified_name
          elsif :transport == modality
            if characteristic.enumeration.textual_values?
              return "java.lang.String"
            else
              return "java.lang.Integer"
            end
          else
            error("unknown modality #{modality}")
          end
        elsif characteristic.characteristic_type == :struct
          return characteristic.struct.send(struct_key).qualified_name
        else
          return Domgen::Java::TYPE_MAP[characteristic.characteristic_type.to_s] || characteristic.characteristic_type.to_s
        end
      end

      def primitive?(modality = :default)
        return false if characteristic.nullable?
        return false if (characteristic.respond_to?(:generated_value?) && characteristic.generated_value?)
        return true if characteristic.integer? || characteristic.boolean?
        return true if :transport == modality && characteristic.enumeration? && characteristic.enumeration.numeric_values?

        if :default == modality
          return false
        elsif :transport == modality
          return false unless characteristic.reference?
          return characteristic.referenced_entity.primary_key.integer? || characteristic.referenced_entity.primary_key.boolean?
        else
          error("unknown modality #{modality}")
        end
      end

      def primitive_java_type(modality = :default)
        return "int" if characteristic.integer?
        return "boolean" if characteristic.boolean?
        if :transport == modality
          if characteristic.reference?
            return characteristic.referenced_entity.primary_key.send(facet_key).primitive_java_type
          elsif characteristic.enumeration? && characteristic.enumeration.numeric_values?
            return "int"
          end
        end
        error("primitive_java_type invoked for non primitive method")
      end

      def characteristic_type(modality = :default)
        if :default == modality
          return characteristic.characteristic_type
        elsif :transport == modality
          return characteristic.reference? ? characteristic.referenced_entity.primary_key.send(facet_key).characteristic_type : characteristic.characteristic_type
        else
          error("unknown modality #{modality}")
        end
      end

      protected

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

      def struct_key
        :jaxb
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
