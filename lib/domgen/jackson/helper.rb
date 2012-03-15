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
        s = ''
        s << "@org.codehaus.jackson.annotate.JsonProperty(\"#{field.json.name}\")\n"
        if field.date?
          if field.collection?
            if field.collection_type == :sequence
              s << "  @org.codehaus.jackson.map.annotate.JsonSerialize( using = org.realityforge.replicant.server.json.jackson.DateListSerializer.class )\n"
              s << "  @org.codehaus.jackson.map.annotate.JsonDeserialize( using = org.realityforge.replicant.server.json.jackson.DateListDeserializer.class )\n"
            else
              s << "  @org.codehaus.jackson.map.annotate.JsonSerialize( using = org.realityforge.replicant.server.json.jackson.DateSetSerializer.class )\n"
              s << "  @org.codehaus.jackson.map.annotate.JsonDeserialize( using = org.realityforge.replicant.server.json.jackson.DateSetDeserializer.class )\n"
            end
          else
            s << "  @org.codehaus.jackson.map.annotate.JsonSerialize( using = org.realityforge.replicant.server.json.jackson.DateSerializer.class )\n"
            s << "  @org.codehaus.jackson.map.annotate.JsonDeserialize( using = org.realityforge.replicant.server.json.jackson.DateDeserializer.class )\n"
          end
        end
        s
      end
    end
  end
end
