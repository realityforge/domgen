module Domgen

  module Faceted

    def facet_enabled?(facet)
      all_enabled_facets.include?(facet)
    end

    protected

    def activate_facets
      self.all_enabled_facets.each do |facet_key|
        facet = FacetManager.facet_by_name(facet_key)
        facet.enable_on(self)
      end
    end

    def activate_facet(facet_key)
      FacetManager.facet_by_name(facet_key).enable_on(self)
    end

    def deactivate_facet(facet_key)
      FacetManager.facet_by_name(facet_key).disable_on(self)
    end

    def extension_point(action)
      self.all_enabled_facets.each do |facet_key|
        # Need to check for the magic facet_X method rather than X method directly as
        # sometimes there is a global method of the same name.
        extension_object = (self.send "facet_#{facet_key}" rescue nil)
        if extension_object && extension_object.respond_to?(action)
          extension_object.send action
        end
      end
    end

    def enabled_facets
      @enabled_facets ||= []
    end

    def disabled_facets
      @disabled_facets ||= []
    end

    def all_enabled_facets
      enabled_facets + (self.respond_to?(:facet_parent) ? facet_parent.all_enabled_facets : []) - disabled_facets
    end
  end

  module GenerateFacet
    def enable_facet(key)
      Domgen.error("Facet #{key} already enabled.") if self.enabled_facets.include?(key)
      self.enabled_facets << key
      self.activate_facet(key)
    end

    def disable_facet(key)
      Domgen.error("Facet #{key} already disabled.") if self.disabled_facets.include?(key)
      self.disabled_facets << key
      self.deactivate_facet(key)
    end
  end

  def self.FacetedElement(parent_key)
    type = self.ParentedElement(parent_key, "self.activate_facets")
    type.class_eval(<<-CODE)
        def facet_parent
          self.#{parent_key}
        end

        include Domgen::Faceted
    CODE
    type
  end

  class Facet
    attr_reader :key
    attr_reader :extension_map

    def initialize(key, extension_map)
      extension_map.each_pair do |source_class, extension_class|
        Domgen.error("Facet #{key}: Unknown source class supplied in map '#{source_class.name}'") unless FacetManager.valid_source_classes.include?(source_class)
        Domgen.error("Facet #{key}: Extension class is not a class. '#{extension_class}'") unless extension_class.is_a?(Class)
      end
      @key = key
      @extension_map = extension_map
    end

    def enable_on(object)
      extension_class = self.extension_map[object.class]
      return unless extension_class

      # We need to define two method as in some cases the method name used by the facet conflicts
      # with a global method. i.e. :ruby is a global method when buildr/jruby is loaded and thus no
      # way to determine if a particular element supports a facet via respond_to?
      object.instance_eval("def facet_#{self.key}; @#{self.key} ||= #{extension_class.name}.new(self); end")
      object.instance_eval("def #{self.key}; self.facet_#{self.key}; end")
      Logger.debug "Facet '#{key}' enabled for #{object.class} by adding extension #{extension_class}"
    end

    def disable_on(object)
      extension_class = self.extension_map[object.class]
      return unless extension_class
      object.instance_eval("def #{self.key}; Domgen.error(\"Facet #{self.key} has been disabled\"); end")
      object.remove_instance_variable(:"@#{self.key}")
      Logger.debug "Facet '#{key}' disabled for #{object.class} by removing extension #{extension_class}"
    end
  end

  class FacetManager
    class << self
      def define_facet(key, extension_map)
        Domgen.error("Attempting to redefine facet #{key}") if facet_map[key.to_s]
        facet_map[key.to_s] = Facet.new(key, extension_map)
      end

      def facet_by_name(key)
        facet = facet_map[key.to_s]
        Domgen.error("Unknown facet '#{key}'") unless facet
        facet
      end

      def valid_source_classes
        [
          Domgen::Attribute, Domgen::InverseElement, Domgen::ObjectType,
          Domgen::Service, Domgen::Method, Domgen::Parameter, Domgen::Exception, Domgen::Result,
          Domgen::DataModule, Domgen::Repository
        ]
      end

      private

      # Map a facet key to a map. The map maps types to extension classes
      def facet_map
        @facets ||= Domgen::OrderedHash.new
      end
    end
  end
end