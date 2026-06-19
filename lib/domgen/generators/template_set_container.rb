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

    module TemplateSetContainer
      def template_sets
        template_set_map.values
      end

      def template_set(name, options = {}, &block)
        if name.is_a?(Hash) && name.size == 1
          req = name.values[0]
          options = options.dup
          options[:required_template_sets] = req.is_a?(Array) ? req : [req]
          name = name.keys[0]
        end
        new_template_set(name.to_s, options, &block)
      end

      def template_set_by_name?(name)
        !!template_set_map[name.to_s]
      end

      def template_set_by_name(name)
        template_set = template_set_map[name.to_s]
        Domgen.error("Unable to locate template_set #{name}") unless template_set
        template_set
      end

      def target_manager
        @target_manager ||= Domgen::Generators::TargetManager.new(self)
      end

      def generator
        @generator ||= Domgen::Generators::Generator.new(self)
      end

      # A hook to control whether certain paths in model should
      # be follow when collecting generation targets
      def handle_subelement?(object, sub_feature_key)
        true
      end

      # Hook for deriving the default set of helpers when defining
      # templates using the artifact DSL. Typically this is overridden
      # in framework specific template set containers
      def derive_default_helpers(options)
        []
      end

      protected

      def register_template_set(template_set)
        Domgen.error("Attempting to redefine template_set #{template_set.name}") if template_set_map[template_set.name.to_s]
        template_set_map[template_set.name.to_s] = template_set
      end

      def new_template_set(name, options, &block)
        Domgen::Generators::StandardTemplateSet.new(self, name.to_s, options, &block)
      end

      def new_generator
        Domgen.error('new_generator not implemented')
      end

      private

      def template_set_map
        @template_sets ||= {}
      end
    end
  end
end
