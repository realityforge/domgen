#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Domgen
  module Jackson
    module Helper
      def jackson_class_annotations(struct)
        s = ''
        s << "@org.codehaus.jackson.annotate.JsonAutoDetect( value = org.codehaus.jackson.annotate.JsonMethod.NONE )\n"
        s << "@org.codehaus.jackson.annotate.JsonTypeName( \"#{struct.json.name}\" )\n"
        s << "@org.codehaus.jackson.annotate.JsonPropertyOrder({#{struct.fields.collect{|field| "\"#{Domgen::Naming.camelize(field.name)}\""}.join(", ")}})"
        s
      end

      def jackson_field_annotation(field)
        s = ''
        s << "@org.codehaus.jackson.annotate.JsonProperty(\"#{field.json.name}\")\n"
        if field.enumeration? && field.enumeration.numeric_values?
          if field.collection?
            Domgen.error("Attempted to use a collection of enumerations which is currently unsupported")
          else
            s << "  @org.codehaus.jackson.map.annotate.JsonDeserialize( using = #{field.enumeration.ee.qualified_name}.Deserializer.class )\n"
          end
        elsif field.date?
          if field.collection?
            if field.collection_type == :sequence
              s << "  @org.codehaus.jackson.map.annotate.JsonSerialize( using = org.realityforge.gwt.datatypes.server.date.jackson.DateListSerializer.class )\n"
              s << "  @org.codehaus.jackson.map.annotate.JsonDeserialize( using = org.realityforge.gwt.datatypes.server.date.jackson.DateListDeserializer.class )\n"
            else
              s << "  @org.codehaus.jackson.map.annotate.JsonSerialize( using = org.realityforge.gwt.datatypes.server.date.jackson.DateSetSerializer.class )\n"
              s << "  @org.codehaus.jackson.map.annotate.JsonDeserialize( using = org.realityforge.gwt.datatypes.server.date.jackson.DateSetDeserializer.class )\n"
            end
          else
            s << "  @org.codehaus.jackson.map.annotate.JsonSerialize( using = org.realityforge.gwt.datatypes.server.date.jackson.DateSerializer.class )\n"
            s << "  @org.codehaus.jackson.map.annotate.JsonDeserialize( using = org.realityforge.gwt.datatypes.server.date.jackson.DateDeserializer.class )\n"
          end
        end
        s
      end
    end
  end
end
