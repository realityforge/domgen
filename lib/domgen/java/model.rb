module Domgen
  module Java
    TYPE_MAP = {"integer" => "java.lang.Integer",
                "boolean" => "java.lang.Boolean",
                "datetime" => "java.util.Date",
                "text" => "java.lang.String",
                "void" => "java.lang.Void"}

    module JavaCharacteristic
      def name(modality = :default)
        if :default == modality
          return characteristic.name
        elsif :boundary == modality || :transport == modality
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

      def java_component_type(modality = :default)
        if characteristic.reference?
          if :default == modality
            return characteristic.referenced_entity.send(entity_key).qualified_name
          elsif :boundary == modality || :transport == modality
            return characteristic.referenced_entity.primary_key.send(entity_key).non_primitive_java_type(modality)
          else
            error("unknown modality #{modality}")
          end
        elsif characteristic.enumeration?
          if :default == modality || :boundary == modality
            return characteristic.enumeration.send(enumeration_key).qualified_name
          elsif :transport == modality
            if characteristic.enumeration.textual_values?
              return "java.lang.String"
            else
              return "java.lang.Integer"
            end
          else
            error("unknown modality #{modality}")
          end
        elsif characteristic.struct?
          if :default == modality || :boundary == modality
            return characteristic.struct.send(struct_key).qualified_name
          elsif :transport == modality
            return "java.lang.String"
          else
            error("unknown modality #{modality}")
          end
        elsif characteristic.date?
          return date_java_type
        else
          return Domgen::Java::TYPE_MAP[characteristic.characteristic_type.to_s] || characteristic.characteristic_type.to_s
        end
      end

      def non_primitive_java_type(modality = :default)
        component_type = java_component_type(modality)
        if :none == characteristic.collection_type
          return component_type
        elsif :sequence == characteristic.collection_type
          "java.util.List<#{component_type}>"
        else #:set == characteristic.collection_type
          "java.util.Set<#{component_type}>"
        end
      end

      def primitive?(modality = :default)
        return false if characteristic.collection?
        return false if characteristic.nullable?
        return false if (characteristic.respond_to?(:generated_value?) && characteristic.generated_value?)
        return true if characteristic.integer? || characteristic.boolean?
        return true if :transport == modality && characteristic.enumeration? && characteristic.enumeration.numeric_values?

        if :default == modality
          return false
        elsif :boundary == modality || :transport == modality
          return false unless characteristic.reference?
          return characteristic.referenced_entity.primary_key.integer? || characteristic.referenced_entity.primary_key.boolean?
        else
          error("unknown modality #{modality}")
        end
      end

      def primitive_java_type(modality = :default)
        return "int" if characteristic.integer?
        return "boolean" if characteristic.boolean?
        if (:boundary == modality || :transport == modality) && characteristic.reference?
          return characteristic.referenced_entity.primary_key.send(entity_key).primitive_java_type
        elsif :transport == modality && characteristic.enumeration? && characteristic.enumeration.numeric_values?
          return "int"
        end
        error("primitive_java_type invoked for non primitive method")
      end

      def characteristic_type(modality = :default)
        if :default == modality
          return characteristic.characteristic_type
        elsif :boundary == modality || :transport == modality
          return characteristic.reference? ? characteristic.referenced_entity.primary_key.send(entity_key).characteristic_type : characteristic.characteristic_type
        else
          error("unknown modality #{modality}")
        end
      end

      protected

      def characteristic
        raise "characteristic unimplemented"
      end

      def entity_key
        raise "entity_key unimplemented"
      end

      def enumeration_key
        raise "enumeration_key unimplemented"
      end

      def struct_key
        raise "struct_key unimplemented"
      end
    end

    module EEJavaCharacteristic
      include JavaCharacteristic

      protected

      def entity_key
        :jpa
      end

      def enumeration_key
        :ee
      end

      def struct_key
        :ee
      end

      def date_java_type
        "java.util.Date"
      end
    end

    module ImitJavaCharacteristic
      include JavaCharacteristic

      protected

      def enumeration_key
        :imit
      end

      def entity_key
        :imit
      end

      def struct_key
        :imit
      end

      def date_java_type
        "org.realityforge.replicant.client.RDate"
      end
    end

    module JavaPackage
      attr_writer :entity_package

      def entity_package
        @entity_package || "#{data_module.repository.send(facet_key).entity_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      attr_writer :service_package

      def service_package
        @service_package || "#{data_module.repository.send(facet_key).service_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      attr_writer :data_type_package

      def data_type_package
        @data_type_package || "#{data_module.repository.send(facet_key).data_type_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      protected

      def facet_key
        raise "facet_key unimplemented"
      end
    end

    module JavaApplication
      attr_writer :package

      def package
        @package || "#{Domgen::Naming.underscore(repository.name)}.#{default_package_root}"
      end

      attr_writer :entity_package

      def entity_package
        @entity_package || "#{package}.entity"
      end

      attr_writer :service_package

      def service_package
        @service_package || "#{package}.service"
      end

      attr_writer :data_type_package

      def data_type_package
        @data_type_package || "#{package}.data_type"
      end

      def default_package_root
        raise "default_package_root unimplemented"
      end
    end

    module ServerJavaApplication
      include JavaApplication

      protected

      def default_package_root
        "server"
      end
    end

    module ClientJavaApplication
      include JavaApplication

      protected

      def default_package_root
        "client"
      end
    end
  end
end
