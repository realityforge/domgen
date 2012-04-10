module Domgen
  module Java
    module Helper
      def nullability_annotation(is_nullable)
        is_nullable ? "@javax.annotation.Nullable" : "@javax.annotation.Nonnull"
      end

      def annotated_type(characteristic, characteristic_key, modality = :default)
        extension = characteristic.send(characteristic_key)
        if extension.primitive?(modality) || extension.java_type(modality).to_s == 'void'
          return extension.java_type(modality)
        else
          return "#{nullability_annotation(characteristic.nullable?)} #{extension.java_type(modality)}"
        end
      end

      def getter_prefix(attribute)
        attribute.boolean? ? "is" : "get"
      end

      def description_javadoc_for(element, depth = "  ")
        description = element.tags[:Description]
        return '' unless description
        return <<JAVADOC
#{depth}/**
#{depth} * #{description.gsub(/\n+\Z/,"").gsub("\n\n","\n<br />\n").gsub("\n","\n#{depth} * ")}
#{depth} */
JAVADOC
      end

      def modality_default_to_transport(variable_name, characteristic, characteristic_key)
        extension = characteristic.send(characteristic_key)

        return variable_name if extension.java_type == extension.java_type(:boundary)

        transform = variable_name
        if characteristic.characteristic_type == :enumeration
          if characteristic.enumeration.numeric_values?
            transform = "#{variable_name}.ordinal()"
          else
            transform = "#{variable_name}.name()"
          end
        elsif characteristic.characteristic_type == :reference
          transform = "#{variable_name}.get#{characteristic.referenced_entity.primary_key.name}()"
        end
        if characteristic.nullable?
          transform = "null == #{variable_name} ? null : #{transform}"
        end
        transform
      end

      def modality_boundary_to_default(variable_name, characteristic, characteristic_key)
        extension = characteristic.send(characteristic_key)

        return variable_name if extension.java_type == extension.java_type(:boundary)
        return "$#{variable_name}" if characteristic.reference? && characteristic.collection?

        transform = variable_name
        if characteristic.characteristic_type == :reference
          transform = "_#{characteristic.referenced_entity.qualified_name.gsub('.','')}DAO.getBy#{characteristic.referenced_entity.primary_key.name}( #{variable_name} )"
        end
        if characteristic.nullable? && transform != variable_name
          transform = "(null == #{variable_name} ? null : #{transform})"
        end
        transform
      end
    end
  end
end
