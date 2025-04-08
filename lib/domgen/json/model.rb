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
  module JSON
    def self.include_json(type, parent_key)
      type.class_eval(<<-RUBY)
      attr_writer :name

      def name
        @name || Reality::Naming.jsonize(#{parent_key}.name)
      end
      RUBY
    end
  end

  FacetManager.facet(:json) do |facet|
    facet.enhance(EnumerationSet) do
      Domgen::JSON.include_json(self, :enumeration)
    end

    facet.enhance(Struct) do
      Domgen::JSON.include_json(self, :struct)

      # Override name to strip out DTO/VO suffix
      def name
        return @name if @name
        candidate = Reality::Naming.jsonize(struct.name)
        return candidate[0, candidate.size-4] if candidate =~ /_dto$/
        return candidate[0, candidate.size-3] if candidate =~ /_vo$/
        return candidate
      end
    end

    facet.enhance(StructField) do
      Domgen::JSON.include_json(self, :field)
    end

    facet.enhance(ExceptionParameter) do
      Domgen::JSON.include_json(self, :parameter)
    end
  end
end
