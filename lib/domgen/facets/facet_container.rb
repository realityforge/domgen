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
    module FacetContainer
      def self.extended(base)
        base.class_eval 'module FacetDefinitions; end'
      end

      def facet?(name)
        facet_by_name?(name)
      end

      def facet_by_name?(name)
        !!facet_map[name.to_s]
      end

      def facet_by_name(name)
        facet = facet_map[name.to_s]
        Domgen.error("Unknown facet '#{name}'") unless facet
        facet
      end

      def facet(definition, options = {}, &block)
        Domgen.error("Unknown definition form '#{definition.inspect}'") unless (definition.is_a?(Symbol) || (definition.is_a?(Hash) && 1 == definition.size))
        key = (definition.is_a?(Hash) ? definition.keys[0] : definition).to_sym
        required_facets = definition.is_a?(Hash) ? definition.values[0] : []
        Domgen::Facets::Facet.new(self, key, { :required_facets => required_facets }.merge(options), &block)
      end

      def facet_keys
        facet_map.keys
      end

      def facets
        facet_map.values
      end

      def lock!
        @locked = true
      end

      def locked?
        !!(@locked ||= nil)
      end

      def extension_manager
        @extension_manager ||= Domgen::Facets::ExtensionManager.new
      end

      def target_manager
        @target_manager ||= Domgen::Facets::TargetManager.new(self)
      end

      def facet_definitions
        self.const_get(:FacetDefinitions)
      end

      def dependent_facets(*facet_keys)
        facet_keys = facet_keys[0] if facet_keys.size == 1 && facet_keys[0].is_a?(Array)
        to_process = facet_keys.dup
        results = []
        until to_process.empty?
          facet_key = to_process.pop
          results << facet_key
          facet = facet_by_name(facet_key)
          facet.required_facets.each do |required_facet_key|
            if !results.include?(required_facet_key) && !to_process.include?(required_facet_key)
              to_process << required_facet_key
            end
          end
        end
        results
      end

      def activate_facet(object, facet_name)
        return if object.facet_enabled?(facet_name)

        facet = facet_by_name(facet_name)
        facet.required_facets.each do |required_facet_key|
          activate_facet(object, required_facet_key)
        end
        facet.suggested_facets.each do |suggested_facet_key|
          activate_facet(object, suggested_facet_key)
        end
        object.send(:"_enable_facet_#{facet_name}!")

        each_contained_model_object(object) do |child|
          activate_facet(child, facet_name)
        end
      end

      def deactivate_facet(object, facet_name)
        return unless object.facet_enabled?(facet_name)
        each_contained_model_object(object) do |child|
          deactivate_facet(child, facet_name)
        end

        facets.each do |facet|
          if facet.required_facets.include?(facet_name)
            deactivate_facet(object, facet.key)
          end
        end
        object.send(:"_disable_facet_#{facet_name}!")
      end

      def extension_point(object, action)
        # noinspection RubyNestedTernaryOperatorsInspection
        name = object.respond_to?(:qualified_name) ? object.qualified_name : object.respond_to?(:name) ? object.name : object.to_s
        if object.respond_to?(action, true)
          Domgen.debug "Running '#{action}' hook on #{object.class} #{name}"
          object.send(action)
        end
        object.enabled_facets.each do |facet_name|
          # Need to skip facets that have been disabled within same round
          next unless object.facet_enabled?(facet_name)
          # Need to check for the magic facet_X method rather than X method directly as
          # sometimes there is a global method of the same name.
          method_name = "facet_#{facet_name}"
          extension_object = object.respond_to?(method_name) ? object.send(method_name) : nil
          if extension_object && extension_object.respond_to?(action, true)
            Domgen.debug "Running '#{action}' hook on #{facet_name} facet of #{object.class} #{name}"
            extension_object.send(action)
          end
        end
        each_contained_model_object(object) do |child|
          extension_point(child, action)
        end
      end

      private

      def each_contained_model_object(object)
        top_target = target_manager.target_by_model_class(object.class)
        # noinspection RubyArgCount
        target_manager.targets_by_container(top_target.key).each do |target|
          next unless handle_sub_feature?(object, target.key)
          elements = object.send(target.access_method) || []
          elements = elements.is_a?(Array) ? elements : [elements]
          elements.each do |child|
            yield child
          end
        end
      end

      def handle_sub_feature?(object, sub_feature_key)
        true
      end

      def register_facet(facet)
        target_manager.lock!
        Domgen.error("Attempting to define facet #{facet.key} after facet manager is locked") if locked?
        Domgen.error("Attempting to redefine facet #{facet.key}") if facet_map[facet.key.to_s]
        facet_map[facet.key.to_s] = facet
      end

      # Map a facet key to a map. The map maps types to extension classes
      def facet_map
        @facets ||= {}
      end
    end
  end
end
