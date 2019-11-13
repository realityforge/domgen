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
  module Graphql
    module Helper
      def has_description?(input)
        input.graphql.description.to_s.strip != ''
      end

      def description_to_string(input)
        escape_description_to_string(input.graphql.description)
      end

      def description_as_string(input, indent)
        description_string(input.graphql.description.to_s.strip, indent)
      end

      def deprecate_directive(value)
        value.graphql.deprecation_reason ? " @deprecated(reason: \"#{value.graphql.deprecation_reason}\")" : ""
      end

      def numeric_directive(characteristic)
        characteristic.primary_key? && characteristic.integer? ? ' @numeric': ''
      end

      def input_numeric_directive(characteristic)
        characteristic.reference? && characteristic.referenced_entity.primary_key.integer? ? ' @numeric': ''
      end

      def escape_description_to_string(description)
        j_escape_string(description.to_s.strip).gsub("\n", "\\n\" + \"")
      end

      def description_string(description, indent)
        if description.nil? || description == ''
          ''
        elsif description.include?("\n")
          "#{' ' * indent}\"\"\"\n" + description.split("\n").collect {|line| "#{' ' * (indent + 2)}#{line}"}.join("\n") + "\n#{' ' * indent}\"\"\"\n"
        else
          "#{' ' * indent}\"#{description}\"\n"
        end
      end

      def graphql_resolve_parameter(parameter)
        transport_value = "args.get#{parameter.name}()"
        accessor =
          if parameter.reference? && !parameter.collection?
            "asEntity( e, #{parameter.ejb.java_type}.class, \"#{parameter.graphql.name}\", \"#{parameter.referenced_entity.graphql.name}\", #{transport_value} )"
          elsif parameter.reference? && parameter.collection?
            "asEntityList( e, #{parameter.ejb.java_component_type}.class, \"#{parameter.graphql.name}\", \"#{parameter.referenced_entity.graphql.name}\", #{transport_value} )"
          elsif parameter.struct? && !parameter.collection?
            "asStruct( #{transport_value} )"
          elsif parameter.struct? && parameter.collection?
            "#{transport_value}.stream().map( this::asStruct ).collect( java.util.stream.Collectors.toList() )"
          else
            transport_value
          end
        accessor = "null == #{transport_value} ? null : #{accessor}" if parameter.nullable? && (parameter.reference? || parameter.struct?)
        accessor
      end

    end
  end
end
