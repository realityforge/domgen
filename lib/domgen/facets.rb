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
        extension_object = (self.send facet_key rescue nil)
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

end