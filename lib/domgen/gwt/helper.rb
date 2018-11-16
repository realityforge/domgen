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
          base_type = field.nullable? && field.integer? ? 'java.lang.Double' : field.gwt.java_component_type(field.struct? ? :boundary : :transport)

          "#{base_type}[]"
        else
          field.nullable? && field.integer? ? 'java.lang.Double' : field.gwt.java_type(field.struct? ? :boundary : :transport)
        end
      end
    end
  end
end
