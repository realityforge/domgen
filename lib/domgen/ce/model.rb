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
  FacetManager.facet(:ce => [:java]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication
    end

    facet.enhance(DataModule) do
      include Domgen::Java::ImitJavaPackage
    end

    facet.enhance(EnumerationSet) do
      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.ce.client_data_type_package}.#{name}"
      end
    end
  end
end
