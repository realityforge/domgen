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

    # A descriptor describing a type in the system that a template can be generated from.
    class Target
      def initialize(target_manager, key, container_key, options)
        @target_manager = target_manager
        @key = key.to_sym
        @facet_key = options[:facet_key]
        @qualified_key = (@facet_key.nil? ? @key : "#{@facet_key}.#{@key}").to_sym
        @access_method = options[:access_method] || Domgen::Naming.pluralize(@key)
        @container_key = container_key.nil? ? nil : container_key.to_sym

        if @container_key && !target_manager.target_by_key?(@container_key)
          Domgen.error("Target '#{key}' defines container as '#{@container_key}' but no such target exists.")
        end

        @target_manager.send(:register_target, self)
      end

      attr_reader :target_manager
      attr_reader :qualified_key
      attr_reader :key
      attr_reader :container_key
      attr_reader :access_method
      attr_reader :facet_key

      def standard?
        facet_key.nil?
      end
    end

    class TargetManager
      attr_reader :container

      def initialize(container)
        @container = container
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

      def target(key, container_key = nil, options = {})
        Target.new(self, key, container_key, options)
      end

      def targets_by_container(container_key)
        target_map.values.select { |target| target.container_key == container_key }
      end

      def reset_targets
        target_map.clear
      end

      private

      def register_target(target)
        Domgen.error("Attempting to redefine target #{target.qualified_key}") if target_map[target.qualified_key]
        target_map[target.qualified_key] = target
      end

      def target_map
        @target_map ||= {}
      end
    end
  end
end
