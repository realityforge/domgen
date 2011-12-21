module Domgen
  module EJB
    class EjbClass < Domgen.ParentedElement(:service)
      attr_writer :name

      def name
        @name || service.qualified_name
      end

      def facade_name
        "#{name}Facade"
      end

      attr_writer :service_name

      def service_name
        @service_name || service.name
      end

      def qualified_service_name
        "#{service.data_module.ejb.service_package}.#{service_name}"
      end

      def facade_interface_name
        "#{service_name}Facade"
      end

      def qualified_facade_interface_name
        "#{service.data_module.ejb.service_package}.#{facade_interface_name}"
      end

      def facade_implementation_name
        "#{service_name}FacadeImpl"
      end

      def qualified_facade_implementation_name
        "#{service.data_module.ejb.service_package}.#{facade_implementation_name}"
      end

      attr_accessor :facade_extends

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

      attr_accessor :generate_facade

      def generate_facade?
        @generate_facade.nil? ? service.methods.any?{|method| method.parameters.any?{|parameter|parameter.reference?}} : @generate_facade
      end
    end

    class EjbParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class EjbPackage < Domgen.ParentedElement(:data_module)
      attr_writer :service_package

      def service_package
        @service_package || "#{data_module.repository.ejb.service_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      attr_writer :data_type_package

      def data_type_package
        @data_type_package || service_package
      end
    end

    class EjbApplication < Domgen.ParentedElement(:repository)
      attr_writer :service_package

      def service_package
        @service_package || "#{Domgen::Naming.underscore(repository.name)}.server.service"
      end
    end

    class EjbReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class EjbException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.ejb.data_type_package}.#{name}"
      end
    end
  end

  FacetManager.define_facet(:ejb,
                            Service => Domgen::EJB::EjbClass,
                            Parameter => Domgen::EJB::EjbParameter,
                            Exception => Domgen::EJB::EjbException,
                            Result => Domgen::EJB::EjbReturn,
                            DataModule => Domgen::EJB::EjbPackage,
                            Repository => Domgen::EJB::EjbApplication)
end
