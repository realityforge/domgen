module Domgen
  module EJB
    class EjbClass < BaseParentedElement
      def service
        self.parent
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

  Service.add_extension(:ejb, Domgen::EJB::EjbClass)
end
