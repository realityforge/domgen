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
  FacetManager.facet(:giggle => [:graphql]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::JavaClientServerApplication
      include Domgen::Java::BaseJavaGenerator

      attr_writer :server_graphql_package

      def server_graphql_package
        @server_graphql_package || "#{server_package}.graphql"
      end

      def qualified_types_mapping_name
        "#{self.server_package}.types.mapping"
      end
    end
  end
end
