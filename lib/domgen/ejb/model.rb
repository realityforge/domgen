module Domgen
  module EJB
    class EjbClass < Domgen.ParentedElement(:service)
      attr_writer :name

      def name
        @name || service.qualified_name
      end

      attr_writer :local

      def local?
        @local.nil? ? true : @local
      end

      def remote?
        !local?
      end
    end
  end

  FacetManager.define_facet(:ejb,
                            Service => Domgen::EJB::EjbClass)
end
