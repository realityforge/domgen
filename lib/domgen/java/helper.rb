module Domgen
  module Java
    module Helper
      def nullability_annotation(is_nullable)
        is_nullable ? "@javax.annotation.Nullable" : "@javax.annotation.Nonnull"
      end

      def annotated_type(characteristic, characteristic_key)
        extension = characteristic.send characteristic_key
        if extension.primitive? || extension.java_type.to_s == 'void'
          return extension.java_type
        elsif !characteristic.nullable?
          return "#{nullability_annotation(false)} #{extension.java_type}"
        else
          return "#{nullability_annotation(false)} #{extension.java_type}"
        end
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
