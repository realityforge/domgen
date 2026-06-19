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

    # Module that should be mixed into all model objects that have facets.
    # Implementation should define a method `facet_container` that retrieves
    # the associated manager.
    module Faceted

      def facet_enabled?(facet_key)
        method_name = :"#{facet_key}?"
        self.respond_to?(method_name) ? self.send(method_name) : false
      end

      def facet(facet_key)
        self.send(facet_key)
      end

      def enabled_facets
        (@enabled_facets ||= []).dup
      end

      def enable_facet(key)
        Domgen.error("Facet #{key} already enabled.") if self.facet_enabled?(key)
        self.activate_facet(key)
      end

      def enable_facets!(*keys)
        keys = keys[0] if keys.size == 1 && keys[0].is_a?(Array)
        keys.flatten.each do |key|
          enable_facet(key)
        end
      end

      def enable_facets(*keys)
        keys = keys[0] if keys.size == 1 && keys[0].is_a?(Array)
        keys.flatten.each do |key|
          self.activate_facet(key) unless self.facet_enabled?(key)
        end
      end

      def disable_facet(key)
        Domgen.error("Facet #{key} not enabled.") unless self.facet_enabled?(key)
        self.deactivate_facet(key)
      end

      def disable_facets!(*keys)
        keys = keys[0] if keys.size == 1 && keys[0].is_a?(Array)
        keys.flatten.each do |key|
          disable_facet(key)
        end
      end

      def disable_facets(*keys)
        keys = keys[0] if keys.size == 1 && keys[0].is_a?(Array)
        keys.flatten.each do |key|
          disable_facet(key) if self.facet_enabled?(key)
        end
      end

      def disable_facets_not_in(*keys)
        keys = keys[0] if keys.size == 1 && keys[0].is_a?(Array)
        facets_to_disable = self.enabled_facets - facet_container.dependent_facets(keys)
        facets_to_disable.each do |facet_key|
          self.disable_facet(facet_key) if self.facet_enabled?(facet_key)
        end
      end

      protected

      def extension_point(action)
        Domgen.debug "Model '#{self}' extension point #{action} started"
        facet_container.extension_point(self, action)
        Domgen.debug "Model '#{self}' extension point #{action} completed"
      end

      def activate_facet(facet_key)
        facet_container.activate_facet(self, facet_key)
      end

      def deactivate_facet(facet_key)
        facet_container.deactivate_facet(self, facet_key)
      end
    end
  end
end
