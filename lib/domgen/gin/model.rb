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
  FacetManager.facet(:gin => [:gwt]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      def component_suffix
        'Ginjector'
      end

      def module_suffix
        'GinModule'
      end

      # def post_verify
      #   if repository.dagger?
      #     Domgen.error("Repository named '#{repository.name}' defines incompatible facets dagger and gin")
      #   end
      # end
    end
  end
end