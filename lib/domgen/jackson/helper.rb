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
        s << "@com.fasterxml.jackson.annotation.JsonAutoDetect( fieldVisibility = com.fasterxml.jackson.annotation.JsonAutoDetect.Visibility.ANY, getterVisibility = com.fasterxml.jackson.annotation.JsonAutoDetect.Visibility.NONE, setterVisibility = com.fasterxml.jackson.annotation.JsonAutoDetect.Visibility.NONE, isGetterVisibility = com.fasterxml.jackson.annotation.JsonAutoDetect.Visibility.NONE, creatorVisibility = com.fasterxml.jackson.annotation.JsonAutoDetect.Visibility.NONE )\n"
        s << "@com.fasterxml.jackson.annotation.JsonTypeName( \"#{struct.json.name}\" )\n"
        s << "@com.fasterxml.jackson.annotation.JsonPropertyOrder({#{struct.fields.collect{|field| "\"#{Reality::Naming.camelize(field.name)}\""}.join(', ')}})"
        s
      end

      def jackson_field_annotation(field)
        s = ''
        s << "@com.fasterxml.jackson.annotation.JsonProperty(\"#{field.json.name}\")\n"
        if field.enumeration? && field.enumeration.numeric_values?
          if field.collection?
            Domgen.error('Attempted to use a collection of enumerations which is currently unsupported')
          else
            s << "  @com.fasterxml.jackson.databind.annotation.JsonDeserialize( using = #{field.enumeration.ee.qualified_name}.Deserializer.class )\n"
          end
        elsif field.date?
          date_util_name = field.struct.data_module.repository.jackson.qualified_date_util_name
          if field.collection?
            if field.collection_type == :sequence
              s << "  @com.fasterxml.jackson.databind.annotation.JsonSerialize( using = #{date_util_name}.DateListSerializer.class )\n"
              s << "  @com.fasterxml.jackson.databind.annotation.JsonDeserialize( using = #{date_util_name}.DateListDeserializer.class )\n"
            else
              s << "  @com.fasterxml.jackson.databind.annotation.JsonSerialize( using = #{date_util_name}.DateSetSerializer.class )\n"
              s << "  @com.fasterxml.jackson.databind.annotation.JsonDeserialize( using = #{date_util_name}.DateSetDeserializer.class )\n"
            end
          else
            s << "  @com.fasterxml.jackson.databind.annotation.JsonSerialize( using = #{date_util_name}.DateSerializer.class )\n"
            s << "  @com.fasterxml.jackson.databind.annotation.JsonDeserialize( using = #{date_util_name}.DateDeserializer.class )\n"
          end
        end
        s
      end
    end
  end
end
