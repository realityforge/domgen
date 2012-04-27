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
            return characteristic.referenced_struct.send(struct_key).qualified_name
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
        :gwt
      end

      def entity_key
        :imit
      end

      def struct_key
        :gwt
      end

      def date_java_type
        "org.realityforge.replicant.client.RDate"
      end
    end

    module JavaPackage
      attr_writer :entity_package

      def entity_package
        @entity_package || "#{parent_facet.entity_package}.#{package_key}"
      end

      attr_writer :service_package

      def service_package
        @service_package || "#{parent_facet.service_package}.#{package_key}"
      end

      attr_writer :data_type_package

      def data_type_package
        @data_type_package || "#{parent_facet.data_type_package}.#{package_key}"
      end

      protected

      def facet_key
        raise "facet_key unimplemented"
      end

      def parent_facet
        data_module.repository.send(facet_key)
      end

      def package_key
        Domgen::Naming.underscore(data_module.name)
      end
    end

    module ClientServerJavaPackage
      attr_writer :shared_entity_package

      def shared_entity_package
        @shared_entity_package || "#{parent_facet.shared_entity_package}.#{package_key}"
      end

      attr_writer :shared_service_package

      def shared_service_package
        @shared_service_package || "#{parent_facet.shared_service_package}.#{package_key}"
      end

      attr_writer :shared_data_type_package

      def shared_data_type_package
        @shared_data_type_package || "#{parent_facet.shared_data_type_package}.#{package_key}"
      end

      attr_writer :client_entity_package

      def client_entity_package
        @client_entity_package || "#{parent_facet.client_entity_package}.#{package_key}"
      end

      attr_writer :client_service_package

      def client_service_package
        @client_service_package || "#{parent_facet.client_service_package}.#{package_key}"
      end

      attr_writer :client_data_type_package

      def client_data_type_package
        @client_data_type_package || "#{parent_facet.client_data_type_package}.#{package_key}"
      end

      attr_writer :server_entity_package

      def server_entity_package
        @server_entity_package || "#{parent_facet.server_entity_package}.#{package_key}"
      end

      attr_writer :server_service_package

      def server_service_package
        @server_service_package || "#{parent_facet.server_service_package}.#{package_key}"
      end

      attr_writer :server_data_type_package

      def server_data_type_package
        @server_data_type_package || "#{parent_facet.server_data_type_package}.#{package_key}"
      end

      protected

      def facet_key
        raise "facet_key unimplemented"
      end

      def parent_facet
        data_module.repository.send(facet_key)
      end

      def package_key
        Domgen::Naming.underscore(data_module.name)
      end
    end


    module JavaApplication
      attr_writer :base_package

      def base_package
        @base_package || Domgen::Naming.underscore(repository.name)
      end

      attr_writer :package

      def package
        @package || "#{base_package}.#{default_package_root}"
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

    module JavaClientServerApplication
      attr_writer :base_package

      def base_package
        @base_package || Domgen::Naming.underscore(repository.name)
      end

      attr_writer :package

      def package
        @package || (default_package_root ? "#{base_package}.#{default_package_root}" : base_package)
      end

      attr_writer :shared_package

      def shared_package
        @shared_package || "#{package}.shared"
      end

      attr_writer :shared_data_type_package

      def shared_data_type_package
        @shared_data_type_package || "#{shared_package}.data_type"
      end

      attr_writer :shared_service_package

      def shared_service_package
        @shared_service_package || "#{shared_package}.service"
      end

      attr_writer :shared_entity_package

      def shared_entity_package
        @shared_entity_package || "#{shared_package}.entity"
      end

      attr_writer :client_package

      def client_package
        @client_package || "#{package}.client"
      end

      attr_writer :client_service_package

      def client_service_package
        @client_service_package || "#{client_package}.service"
      end

      attr_writer :client_data_type_package

      def client_data_type_package
        @client_data_type_package || "#{client_package}.data_type"
      end

      attr_writer :client_entity_package

      def client_entity_package
        @client_entity_package || "#{client_package}.entity"
      end

      attr_writer :server_package

      def server_package
        @server_package || "#{package}.server"
      end

      attr_writer :server_service_package

      def server_service_package
        @server_service_package || "#{server_package}.service"
      end

      attr_writer :server_data_type_package

      def server_data_type_package
        @server_data_type_package || "#{server_package}.data_type"
      end

      attr_writer :server_entity_package

      def server_entity_package
        @server_entity_package || "#{server_package}.entity"
      end

      def default_package_root
        nil
      end
    end
  end
end
