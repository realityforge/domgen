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

  module Faceted

    def facet_enabled?(facet_key)
      FacetManager.facet_enabled?(facet_key, self)
    end

    def facet(facet_key)
      self.send(facet_key)
    end

    def complete
      extension_point(:pre_complete)
      extension_point(:perform_complete)
      extension_point(:post_complete)
    end

    def verify
      extension_point(:pre_verify)
      extension_point(:perform_verify)
      extension_point(:post_verify)
    end

    def all_enabled_facets
      (enabled_facets + (self.respond_to?(:parent, true) ? parent.all_enabled_facets : [])).uniq - disabled_facets
    end

    protected

    def activate_facets
      FacetManager.activate_facets(self, all_enabled_facets)
    end

    def activate_facet(facet_key)
      FacetManager.activate_facet(facet_key, self)
    end

    def deactivate_facet(facet_key)
      FacetManager.deactivate_facet(facet_key, self)
    end

    def extension_point(action)
      Logger.debug "Facet '#{self}' extension point #{action} started"
      FacetManager.extension_point(self, action)
      Logger.debug "Facet '#{self}' extension point #{action} completed"
    end

    def enabled_facets
      @enabled_facets ||= []
    end

    def disabled_facets
      @disabled_facets ||= []
    end
  end

  module GenerateFacet
    def enable_facet(key)
      Domgen.error("Facet #{key} already enabled.") if self.facet_enabled?(key)
      self.activate_facet(key)
    end

    def disable_facet(key)
      Domgen.error("Facet #{key} not enabled.") unless self.facet_enabled?(key)
      self.deactivate_facet(key)
    end

    def disable_facets_not_in(facets)
      (self.all_enabled_facets - facets).each do |facet_key|
        self.disable_facet(facet_key) if self.facet_enabled?(facet_key)
      end
    end
  end

  def self.FacetedElement(parent_key)
    type = self.ParentedElement(parent_key, "self.activate_facets")
    type.send :include, Domgen::Faceted
    type
  end

  class Facet < BaseElement
    attr_reader :key
    attr_reader :extension_map
    attr_reader :required_facets

    def initialize(key, extension_map, required_facets, options = {}, &block)
      extension_map.each_pair do |source_class, extension_class|
        Domgen.error("Facet #{key}: Unknown source class supplied in map '#{source_class.name}'") unless FacetManager.valid_source_classes.keys.include?(source_class)
        Domgen.error("Facet #{key}: Extension class is not a class. '#{extension_class}'") unless extension_class.is_a?(Class)
        source_class.class_eval("def #{key}?; false; end")
      end
      @key = key
      @extension_map = extension_map
      @required_facets = required_facets
      FacetManager.send :register_facet, self
      super(options, &block)
    end

    def enhance(source_class, &block)
      extension = @extension_map[source_class]
      Domgen.error("Unknown source class #{source_class.name}") unless extension
      extension.class_eval &block
    end

    def enable_on(object)
      extension_class = self.extension_map[object.class]
      return unless extension_class

      # We need to define two method as in some cases the method name used by the facet conflicts
      # with a global method. i.e. :ruby is a global method when buildr/jruby is loaded and thus no
      # way to determine if a particular element supports a facet via respond_to?
      object.instance_eval("def facet_#{self.key}; @#{self.key} ||= #{extension_class.name}.new(self); end")
      object.instance_eval("def #{self.key}; self.facet_#{self.key}; end")
      object.instance_eval("def #{self.key}?; return true; end")
      Logger.debug "Facet '#{key}' enabled for #{object.class} by adding extension #{extension_class}"
    end

    def disable_on(object)
      extension_class = self.extension_map[object.class]
      return unless extension_class
      object.instance_eval("def #{self.key}; Domgen.error(\"Facet #{self.key} has been disabled\"); end")
      object.instance_eval("def #{self.key}?; return false; end")
      object.send(:remove_instance_variable, :"@#{self.key}") rescue
      Logger.debug "Facet '#{key}' disabled for #{object.class} by removing extension #{extension_class}"
    end
  end

  # Container of all facet implementations
  module Facets
  end

  class FacetManager
    class << self
      def define_facet(key, extension_map, required_facets = [])
        Facet.new(key, extension_map, required_facets)
      end

      def register_facet(facet)
        Domgen.error("Attempting to redefine facet #{facet.key}") if facet_map[facet.key.to_s]
        facet_map[facet.key.to_s] = facet
      end

      def facet?(key)
        !!facet_map[key.to_s]
      end

      def facet_by_name(key)
        facet = facet_map[key.to_s]
        Domgen.error("Unknown facet '#{key}'") unless facet
        facet
      end

      def facet(definition, options = {}, &block)
        Domgen.error("Unknown definition form '#{definition.inspect}'") unless (definition.is_a?(Symbol) || (definition.is_a?(Hash) && 1 == definition.size))
        key = (definition.is_a?(Hash) ? definition.keys[0] : definition).to_sym
        Domgen.error("Attempting to redefine facet #{key}") if FacetManager.facet?(key)
        required_facets = definition.is_a?(Hash) ? definition.values[0] : []

        excluded_elements = options[:excluded_elements] || []
        extension_map = {}

        module_name = ::Domgen::Naming.pascal_case(key)
        ::Domgen::Facets.class_eval "module #{module_name}\n end"
        module_instance = ::Domgen::Facets.const_get(module_name)

        valid_source_classes.each_pair do |type, parent_key|
          next if excluded_elements.include?(type)
          extension_name = "#{module_name}#{type.name.gsub(/^.*\:\:(.*)$/, "\\1")}"
          module_instance.class_eval "class #{extension_name} < ::Domgen.ParentedElement(:#{parent_key}); end"
          extension_map[type] = module_instance.const_get(extension_name)
        end

        Facet.new(key, extension_map, required_facets, &block)
      end

      def valid_source_classes
        {
          Domgen::EnumerationSet => :enumeration, Domgen::EnumerationValue => :enumeration_value,
          Domgen::Struct => :struct, Domgen::StructField => :field,
          Domgen::Entity => :entity, Domgen::Attribute => :attribute, Domgen::InverseElement => :inverse,
          Domgen::DataAccessObject => :dao, Domgen::Query => :query, Domgen::QueryParameter => :parameter,
          Domgen::Service => :service, Domgen::Method => :method, Domgen::Parameter => :parameter, Domgen::Result => :result,
          Domgen::Exception => :exception, Domgen::ExceptionParameter => :parameter,
          Domgen::Message => :message, Domgen::MessageParameter => :parameter,
          Domgen::DataModule => :data_module,
          Domgen::Repository => :repository
        }
      end

      def extension_point(object, action)
        if object.respond_to?(action, true)
          Logger.debug "Running '#{action}' hook on #{object.class} #{object.respond_to?(:name) ? object.name : object.to_s}"
          object.send(action)
        end
        facet_map.keys.each do |facet_key|
          if facet_enabled?(facet_key, object)
            # Need to check for the magic facet_X method rather than X method directly as
            # sometimes there is a global method of the same name.
            extension_object = (object.send "facet_#{facet_key}" rescue nil)
            if extension_object && extension_object.respond_to?(action, true)
              Logger.debug "Running '#{action}' hook on #{facet_key} facet of #{object.class} #{object.respond_to?(:qualified_name) ? object.qualified_name : object.name}"
              extension_object.send action
            end
          end
        end
        dependent_features[object.class].each do |sub_feature_key|
          next unless handle_sub_feature?(object, sub_feature_key)
          children = child_features(object, sub_feature_key)
          children.each do |child|
            extension_point(child, action)
          end
        end
      end

      def activate_facets(object, facets)
        facets.each do |facet_key|
          activate_facet(facet_key, object)
        end
      end

      def activate_facet(facet_key, object)
        return if facet_enabled?(facet_key, object)
        facet = facet_by_name(facet_key)
        facet.required_facets.each do |required_facet_key|
          activate_facet(required_facet_key, object)
        end
        facet.enable_on(object)
        object.send(:enabled_facets) << facet_key
        object.send(:disabled_facets).delete(facet_key)

        dependent_features[object.class].each do |sub_feature_key|
          next unless handle_sub_feature?(object, sub_feature_key)
          children = child_features(object, sub_feature_key)
          children.each do |child|
            activate_facet(facet_key, child)
          end
        end
      end

      def deactivate_facet(facet_key, object)
        return unless facet_enabled?(facet_key, object)
        dependent_features[object.class].each do |sub_feature_key|
          next unless handle_sub_feature?(object, sub_feature_key)
          children = child_features(object, sub_feature_key)
          children.each do |child|
            deactivate_facet(facet_key, child)
          end
        end

        facet_map.values.each do |facet|
          if facet.required_facets.include?(facet_key)
            deactivate_facet(facet.key, object)
          end
        end
        facet_by_name(facet_key).disable_on(object)
        object.send(:disabled_facets) << facet_key
        object.send(:enabled_facets).delete(facet_key)
      end

      def facet_enabled?(facet_key, object)
        method_name = :"#{facet_key}?"
        object.respond_to?(method_name) ? object.send(method_name) : false
      end

      private

      def child_features(object, sub_feature_key)
        children = object.send(sub_feature_key)
        children.is_a?(Enumerable) ? children : [children]
      end

      def handle_sub_feature?(object, sub_feature_key)
        return object.reference? if :inverse == sub_feature_key && object.is_a?(Attribute)
        return !object.result.nil? if :result == sub_feature_key && object.is_a?(Method)
        true
      end

      def dependent_features
        {
          Domgen::Repository => [:data_modules],
          Domgen::DataModule => [:services, :exceptions, :entities, :messages, :structs, :enumerations, :daos],
          Domgen::Message => [:parameters],
          Domgen::MessageParameter => [],
          Domgen::Struct => [:fields],
          Domgen::StructField => [],
          Domgen::EnumerationSet => [:values],
          Domgen::EnumerationValue => [],
          Domgen::Entity => [:declared_attributes],
          Domgen::DataAccessObject => [:queries],
          Domgen::Attribute => [:inverse],
          Domgen::InverseElement => [],
          Domgen::Query => [:parameters],
          Domgen::QueryParameter => [],
          Domgen::Service => [:methods],
          Domgen::Method => [:parameters, :result],
          Domgen::Parameter => [],
          Domgen::Exception => [:parameters],
          Domgen::ExceptionParameter => [],
          Domgen::Result => [],
        }
      end

      # Map a facet key to a map. The map maps types to extension classes
      def facet_map
        @facets ||= Domgen::OrderedHash.new
      end
    end
  end
end
