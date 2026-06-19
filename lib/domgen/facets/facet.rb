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

    class Facet < Domgen::BaseElement
      attr_reader :facet_container
      attr_reader :key
      attr_accessor :description
      attr_accessor :required_facets
      attr_accessor :suggested_facets

      def initialize(facet_container, key, options = {}, &block)
        options = options.dup
        @key = key
        @facet_container = facet_container
        @description = nil
        @required_facets = []
        @suggested_facets = []
        @model_extension_instances = {}
        facet_container.send :register_facet, self
        super(options, &block)
        facet_container.target_manager.targets.each do |target|
          target.extension_module.class_eval <<-RUBY
            def #{self.key}?
              !!(@#{self.key}_facet_enabled ||= false)
            end

            private

            def _enable_facet_#{self.key}!
              @#{self.key}_facet_enabled = true
              (@enabled_facets ||= []) << :#{self.key}
            end

            def _disable_facet_#{self.key}!
              @#{self.key}_facet_enabled = false
              @facet_#{self.key} = nil
              (@enabled_facets ||= []).delete(:#{self.key})
            end
          RUBY
        end
      end

      def enhanced?(model_class)
        !!@model_extension_instances[model_class]
      end

      def enhance(model_class, &block)
        facet_container.extension_manager.lock!
        target_manager = facet_container.target_manager
        target = target_manager.target_by_model_class(model_class)

        if @model_extension_instances[model_class].nil?
          extension_name = "#{::Domgen::Naming.pascal_case(self.key)}#{model_class.name.gsub(/^.*\:\:([^\:]+)/, '\1')}Facet"
          definitions = target_manager.container.facet_definitions
          definitions.class_eval(<<-RUBY)
class #{extension_name} < Domgen.base_element(:container_key => :#{target.inverse_access_method}, :pre_config_code => 'pre_init if respond_to?(:pre_init)', :post_config_code => 'post_init if respond_to?(:post_init)')
  def facet_key
    :#{self.key}
  end

  def self.facet_key
    :#{self.key}
  end

  def target_key
    :#{target.key}
  end

  def self.target_key
    :#{target.key}
  end

  def parent
    self.#{target.inverse_access_method}
  end
end
          RUBY
          @model_extension_instances[model_class] = definitions.const_get(extension_name)

          facet_container.extension_manager.instance_extensions.each do |extension|
            @model_extension_instances[model_class].class_eval { include extension }
          end

          facet_container.extension_manager.singleton_extensions.each do |extension|
            @model_extension_instances[model_class].singleton_class.class_eval { include extension }
          end

          target.extension_module.class_eval <<-RUBY
            def #{self.key}
              self.facet_#{self.key}
            end

            def facet_#{self.key}
              Domgen.error("Attempted to access '#{self.key}' facet for model '#{model_class.name}' when facet disabled.") unless #{self.key}?
              @facet_#{self.key} ||= #{@model_extension_instances[model_class].name}.new(self)
            end
          RUBY
        end
        @model_extension_instances[model_class].class_eval(&block) if block_given?
      end
    end
  end
end
