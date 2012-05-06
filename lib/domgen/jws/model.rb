module Domgen
  module JWS
    class JwsClass < Domgen.ParentedElement(:service)
      attr_writer :port_name

      def port_name
        @port_name || service.qualified_name.to_s
      end

      attr_writer :service_name

      def service_name
        @service_name || "#{service.name}WS"
      end

      def qualified_service_name
        "#{service.data_module.jws.service_package}.#{service_name}"
      end

      attr_writer :cxf_annotations

      def cxf_annotations?
        @cxf_annotations.nil? ? service.data_module.jws.cxf_annotations? : @cxf_annotations
      end
    end

    class JwsParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name)
      end

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class JwsMethod < Domgen.ParentedElement(:service)
      def name
        Domgen::Naming.camelize(service.name)
      end
    end

    class JwsPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

      attr_writer :cxf_annotations

      def cxf_annotations?
        @cxf_annotations.nil? ? data_module.repository.jws.cxf_annotations? : @cxf_annotations
      end

      protected

      def facet_key
        :ee
      end
    end

    class JwsApplication < Domgen.ParentedElement(:repository)
      attr_writer :service_name

      # The name of the service under which web services will be anchored
      def service_name
        @service_name || repository.name
      end

      attr_writer :cxf_annotations

      def cxf_annotations?
        @cxf_annotations.nil? ? false : @cxf_annotations
      end
    end

    class JwsReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class JwsException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.jws.data_type_package}.#{name}"
      end
    end
  end

  FacetManager.define_facet(:jws,
                            {
                              Service => Domgen::JWS::JwsClass,
                              Method => Domgen::JWS::JwsMethod,
                              Parameter => Domgen::JWS::JwsParameter,
                              Exception => Domgen::JWS::JwsException,
                              Result => Domgen::JWS::JwsReturn,
                              DataModule => Domgen::JWS::JwsPackage,
                              Repository => Domgen::JWS::JwsApplication
                            },
                            [
                              :jaxb
                            ])
end
