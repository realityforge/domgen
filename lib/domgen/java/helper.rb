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
    end
  end
end
