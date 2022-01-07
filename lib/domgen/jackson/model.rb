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
  FacetManager.facet(:jackson => [:json, :ee]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :date_util, :data_type, :server, :ee, '#{repository.name}DateUtil', :sub_package => 'internal'
      java_artifact :marshalling_test, :data_type, :server, :ee, '#{repository.name}JacksonMarshallingTest'

      def pre_complete
        if repository.ee?
          repository.ee.cdi_scan_excludes << 'com.fasterxml.jackson.annotation.**'
          repository.ee.cdi_scan_excludes << 'com.fasterxml.jackson.core.**'
          repository.ee.cdi_scan_excludes << 'com.fasterxml.jackson.databind.**'
        end
      end
    end

    facet.enhance(Struct) do
      attr_writer :skip_test

      def skip_test?
        @skip_test.nil? ? false : !!@skip_test
      end
    end
  end
end
