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
  FacetManager.facet(:ruby => [:application]) do |facet|
    facet.enhance(DataModule) do
      attr_writer :module_name

      def module_name
        @module_name || data_module.name
      end
    end

    facet.enhance(Entity) do
      attr_writer :classname

      def included_modules
        @included_modules || []
      end

      def include_module(module_name)
        (@included_modules ||= []) << module_name
      end

      def classname
        @classname || entity.name
      end

      def qualified_name
        "::#{entity.data_module.ruby.module_name}::#{classname}"
      end

      def filename
        fqn = qualified_name.gsub(/::/, '/')
        Reality::Naming.underscore(fqn[1..fqn.length])
      end

      facet.enhance(Attribute) do
        attr_writer :validate

        def validate?
          @validate.nil? ? true : @validate
        end
      end
    end
  end
end
