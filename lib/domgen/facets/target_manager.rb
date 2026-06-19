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
  module Facets #nodoc

    # A descriptor describing a base type in the system model.
    class Target
      def initialize(target_manager, model_class, key, container_key, options)
        @target_manager = target_manager
        @model_class = model_class
        @key = key.to_sym
        @access_method = (options[:access_method] || Domgen::Naming.pluralize(@key)).to_sym
        @inverse_access_method = (options[:inverse_access_method] || @key).to_sym
        @container_key = container_key.nil? ? nil : container_key.to_sym
        @extension_module = nil

        if @container_key && !target_manager.target_by_key?(@container_key)
          Domgen.error("Target '#{key}' defines container as '#{@container_key}' but no such target exists.")
        end

        @target_manager.send(:register_target, self)
      end

      attr_reader :target_manager
      attr_reader :model_class
      attr_reader :key
      attr_reader :container_key
      attr_reader :access_method
      attr_reader :inverse_access_method

      def extension_module
        unless @extension_module
          outer_module = target_manager.container.facet_definitions
          module_name = "#{::Domgen::Naming.pascal_case(key)}Extension"
          outer_module.class_eval "module #{module_name}\n end"
          @extension_module = outer_module.const_get(module_name)
          @extension_module.send(:include, Faceted)
          @extension_module.class_eval("def parent; #{self.container_key}; end") if self.container_key
          @extension_module.class_eval 'def facet_container; @facet_container; end'
        end
        @extension_module
      end

      def apply_extension_to(object)
        Domgen.error("Can not apply extension to model object of type #{object.class} as it is not of expected model type #{model_class.name} for target #{key}") unless object.is_a?(model_class)
        Domgen.error("Attempted to apply extension multiple time to model object of type #{model_class.name} for target #{key}") if object.instance_variable_defined?('@facet_extension_active')
        object.class.send(:include, extension_module)
        object.instance_variable_set('@facet_container', target_manager.container)
        object.instance_variable_set('@facet_extension_active', true)

        if self.container_key
          container = object.send(self.container_key)
          container.enabled_facets.each do |facet_key|
            object.send(:"_enable_facet_#{facet_key}!")
          end
        end
        object
      end
    end

    class TargetManager
      attr_reader :container

      def initialize(container)
        @container = container
        @locked = false
      end

      def is_target_valid?(key)
        target_map.keys.include?(key)
      end

      def target_keys
        target_map.keys
      end

      def targets
        target_map.values
      end

      def target_by_key?(key)
        !!target_map[key]
      end

      def target_by_key(key)
        target = target_map[key.to_sym]
        Domgen.error("Can not find target with key '#{key}'") unless target
        target
      end

      def target_by_model_class(model_class)
        target_map.each do |key, target|
          return target if target.model_class == model_class
        end
        Domgen.error("Can not find target with model class '#{model_class.name}'")
      end

      def apply_extension(model)
        container.lock!
        self.target_by_model_class(model.class).apply_extension_to(model)
      end

      def target(model_class, key, container_key = nil, options = {})
        Target.new(self, model_class, key, container_key, options)
      end

      def targets_by_container(container_key)
        target_map.values.select { |target| target.container_key == container_key }
      end

      def lock!
        @locked = true
      end

      def locked?
        !!@locked
      end

      def reset_targets
        target_map.clear
        @locked = false
      end

      private

      def register_target(target)
        Domgen.error("Attempting to define target #{target.key} when targets have been locked.") if locked?
        Domgen.error("Attempting to redefine target #{target.key}") if target_map[target.key]
        target_map[target.key] = target
      end

      def target_map
        @target_map ||= {}
      end
    end
  end
end
