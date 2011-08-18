module Domgen
  module EJB
    class EjbClass < Domgen.ParentedElement(:service)
      attr_writer :local

      def local?
        @local.nil? ? true : @local
      end

      def remote?
        !local?
      end
    end
  end

  Service.add_extension(:ejb, Domgen::EJB::EjbClass)
end
