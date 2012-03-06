module Domgen
  module Jackson
    module Helper
      def jackson_class_annotations(struct)
        s = ''
        s << "@org.codehaus.jackson.annotate.JsonAutoDetect( value = org.codehaus.jackson.annotate.JsonMethod.FIELD )\n"
        s << "@org.codehaus.jackson.annotate.JsonTypeName( \"#{struct.json.name}\" )\n"
        s << "@org.codehaus.jackson.annotate.JsonPropertyOrder({#{struct.fields.collect{|field| "\"#{field.name}\""}.join(", ")}})"
        s
      end

      def jackson_field_annotation(field)
        "@org.codehaus.jackson.annotate.JsonProperty(\"#{field.json.name}\")"
      end
    end
  end
end
