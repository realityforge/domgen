module Domgen
  module EJB
    class EjbClass < Domgen.ParentedElement(:service)
      attr_writer :name

      def name
        @name || service.qualified_name
      end

      def boundary_name
        "#{name}Boundary"
      end

      attr_writer :service_name

      def service_name
        @service_name || service.name
      end

      def qualified_service_name
        "#{service.data_module.ejb.service_package}.#{service_name}"
      end

      def boundary_interface_name
        "Local#{service_name}Boundary"
      end

      def qualified_boundary_interface_name
        "#{service.data_module.ejb.service_package}.#{boundary_interface_name}"
      end

      def remote_service_name
        "Remote#{service_name}"
      end

      def qualified_remote_service_name
        "#{service.data_module.ejb.service_package}.#{remote_service_name}"
      end

      def boundary_implementation_name
        "#{service_name}BoundaryEJB"
      end

      def qualified_boundary_implementation_name
        "#{service.data_module.ejb.service_package}.#{boundary_implementation_name}"
      end

      attr_accessor :boundary_extends

      attr_writer :local

      def local?
        @local.nil? ? true : @local
      end

      def remote=(remote)
        self.local = !remote
      end

      def remote?
        !local?
      end

      attr_accessor :generate_boundary

      def generate_boundary?
        if @generate_boundary.nil?
          return service.jmx? ||
            service.jws? ||
            service.methods.any?{|method| method.parameters.any?{|parameter|parameter.reference?}}
        else
          return @generate_boundary
        end
      end
    end

    class EjbParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class EjbReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class EjbPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

      protected

      def facet_key
        :ee
      end
    end

    class EjbApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ServerJavaApplication
    end
  end

  FacetManager.define_facet(:ejb,
                            {
                              Service => Domgen::EJB::EjbClass,
                              Parameter => Domgen::EJB::EjbParameter,
                              Result => Domgen::EJB::EjbReturn,
                              DataModule => Domgen::EJB::EjbPackage,
                              Repository => Domgen::EJB::EjbApplication
                            },
                            [:ee])
end
