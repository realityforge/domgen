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
  module Gwt
    module Helper

      def characteristic_transport_type(field)
        if field.collection?
          collection_transport_type(field)
        elsif (field.datetime? || field.enumeration? )&& !field.nullable?
          'double'
        elsif field.nullable? && (field.datetime? || field.integer? || field.enumeration?)
          'java.lang.Double'
        elsif !field.nullable? && field.integer?
          'int'
        elsif field.struct?
          field.gwt.java_component_type(:boundary)
        else
          field.gwt.java_component_type(:transport)
        end
      end

      def collection_transport_type(field, size = '')
        base_type =
          if field.datetime? && !field.nullable?
            'double'
          elsif field.datetime? && field.nullable?
            'java.lang.Double'
          elsif field.integer?
            'java.lang.Double'
          elsif field.struct?
            field.gwt.java_component_type(:boundary)
          else
            field.gwt.java_component_type(:transport)
          end

        "#{base_type}[#{size}]"
      end
    end
  end
end
