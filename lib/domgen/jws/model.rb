module Domgen
  module JWS
    class JwsClass < Domgen.ParentedElement(:service)
      attr_writer :name

      def name
        @name || service.qualified_name.to_s.gsub('.','/')
      end

      attr_writer :service_name

      def service_name
        @service_name || "#{service.name}WS"
      end

      def qualified_service_name
        "#{service.data_module.jws.service_package}.#{service_name}"
      end
    end

    class JwsParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name.to_s)
      end

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class JwsMethod < Domgen.ParentedElement(:service)
      def name
        Domgen::Naming.camelize(service.name.to_s)
      end
    end

    class JwsPackage < Domgen.ParentedElement(:data_module)
      attr_writer :service_package

      def service_package
        @service_package || "#{data_module.repository.jws.service_package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      attr_writer :data_type_package

      def data_type_package
        @data_type_package || service_package
      end
    end

    class JwsApplication < Domgen.ParentedElement(:repository)
      attr_writer :service_package

      def service_package
        @service_package || "#{Domgen::Naming.underscore(repository.name)}.server.service"
      end

      attr_writer :service_name

      # The name of the service under which web services will be anchored
      def service_name
        @service_name || repository.name
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
                            Service => Domgen::JWS::JwsClass,
                            Method => Domgen::JWS::JwsMethod,
                            Parameter => Domgen::JWS::JwsParameter,
                            Exception => Domgen::JWS::JwsException,
                            Result => Domgen::JWS::JwsReturn,
                            DataModule => Domgen::JWS::JwsPackage,
                            Repository => Domgen::JWS::JwsApplication)
end
