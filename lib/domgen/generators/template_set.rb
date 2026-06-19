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

module Domgen #nodoc
  module Generators #nodoc

    # A collection of templates
    class TemplateSet < Domgen::BaseElement
      attr_reader :name
      attr_reader :container
      attr_accessor :required_template_sets
      attr_accessor :description

      def initialize(container, name, options = {}, &block)
        @container = container
        @name = name
        @required_template_sets = []
        super(options, &block)
        self.required_template_sets.each do |template_set_name|
          unless container.template_set_by_name?(template_set_name)
            Domgen.error("TemplateSet '#{self.name}' defined requirement on template set '#{template_set_name}' that does not exist.")
          end
        end
        container.send(:register_template_set, self)
      end

      def templates
        template_map.values
      end

      def template_by_name?(name)
        !!template_map[name.to_s]
      end

      def template_by_name(name)
        template = template_map[name.to_s]
        Domgen.error("Unable to locate template #{name}") unless template
        template
      end

      private

      def register_template(template)
        Domgen.error("Template already exists with specified name #{template.name}") if template_map[template.name]
        template_map[template.name] = template
      end

      def template_map
        @templates ||= {}
      end
    end
  end
end
