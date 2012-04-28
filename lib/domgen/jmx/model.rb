module Domgen
  module JMX
    class JmxClass < Domgen.ParentedElement(:service)
      attr_writer :service_name

      def service_name
        @service_name || "#{service.name}MXBean"
      end

      def qualified_service_name
        "#{service.data_module.jmx.service_package}.#{service_name}"
      end
    end

    class JmxParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name)
      end

      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        parameter
      end
    end

    class JmxMethod < Domgen.ParentedElement(:service)
      def name
        Domgen::Naming.camelize(service.name)
      end
    end

    class JmxReturn < Domgen.ParentedElement(:result)
      include Domgen::Java::EEJavaCharacteristic

      protected

      def characteristic
        result
      end
    end

    class JmxException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.jmx.data_type_package}.#{name}"
      end
    end

    class JmxPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

      protected

      def facet_key
        :ee
      end
    end

    class JmxApplication < Domgen.ParentedElement(:repository)
      attr_writer :domain_name

      def domain_name
        @domain_name || repository.name
      end
    end
  end

  FacetManager.define_facet(:jmx,
                            Service => Domgen::JMX::JmxClass,
                            Method => Domgen::JMX::JmxMethod,
                            Parameter => Domgen::JMX::JmxParameter,
                            Exception => Domgen::JMX::JmxException,
                            Result => Domgen::JMX::JmxReturn,
                            DataModule => Domgen::JMX::JmxPackage,
                            Repository => Domgen::JMX::JmxApplication)
end
