module Domgen
  module GWT
    class GwtEvent < Domgen.ParentedElement(:message)
      attr_writer :event_name

      def event_name
        @event_name || "#{message.name}Event"
      end

      def qualified_event_name
        "#{message.data_module.gwt.event_package}.#{event_name}"
      end

      attr_writer :event_handler_name

      def event_handler_name
        @event_handler_name || "#{event_name}Handler"
      end

      def qualified_event_handler_name
        "#{message.data_module.gwt.event_package}.#{event_handler_name}"
      end
    end

    class GwtEventParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name.to_s)
      end

      include Domgen::Java::JavaCharacteristic

      protected

      def characteristic
        parameter
      end

      def entity_to_classname(entity)
        entity.gwt.qualified_name
      end

      def enumeration_to_classname(enumeration)
        enumeration.gwt.qualified_name
      end
    end

    class GwtService < Domgen.ParentedElement(:service)
      attr_writer :xsrf_protected

      def xsrf_protected?
        @xsrf_protected.nil? ? true : @xsrf_protected
      end

      attr_writer :service_name

      def service_name
        @service_name || service.name
      end

      def qualified_service_name
        "#{service.data_module.gwt.shared_package}.#{service_name}"
      end

      def async_service_name
        "#{service_name}Async"
      end

      def qualified_async_service_name
        "#{service.data_module.gwt.shared_package}.#{async_service_name}"
      end

      def servlet_name
        @servlet_name || "#{service_name}Servlet"
      end

      def qualified_servlet_name
        "#{service.data_module.gwt.server_package}.#{servlet_name}"
      end
    end

    class GwtMethod < Domgen.ParentedElement(:method)
      def name
        Domgen::Naming.camelize(method.name.to_s)
      end

      attr_writer :cancelable

      def cancelable?
        @cancelable.nil? ? false : @cancelable
      end
    end

    class GwtModule < Domgen.ParentedElement(:data_module)
      attr_writer :module_name

      def module_name
        @module_name || data_module.name
      end

      attr_writer :package

      def package
        @package || "#{data_module.repository.gwt.package}.#{Domgen::Naming.underscore(data_module.name)}"
      end

      attr_writer :shared_package

      def shared_package
        @shared_package || "#{package}.shared"
      end

      attr_writer :client_package

      def client_package
        @client_package || "#{package}.client"
      end

      attr_writer :event_package

      def event_package
        @event_package || "#{client_package}.event"
      end

      attr_writer :gin_package

      def gin_package
        @gin_package || "#{client_package}.gin"
      end

      attr_writer :server_package

      def server_package
        @server_package || "#{package}.server"
      end

      attr_writer :gin_module_name

      def gin_module_name
        @gin_module_name || "#{data_module.name}ServicesGinModule"
      end

      def qualified_gin_module_name
        "#{gin_package}.#{gin_module_name}"
      end
    end

    class GwtReturn < Domgen.ParentedElement(:result)

      include Domgen::Java::JavaCharacteristic

      protected

      def characteristic
        result
      end

      def entity_to_classname(entity)
        entity.gwt.qualified_name
      end

      def enumeration_to_classname(enumeration)
        enumeration.gwt.qualified_name
      end
    end

    class GwtParameter < Domgen.ParentedElement(:parameter)
      def name
        Domgen::Naming.camelize(parameter.name.to_s)
      end

      include Domgen::Java::JavaCharacteristic

      protected

      def characteristic
        parameter
      end

      def entity_to_classname(entity)
        entity.gwt.qualified_name
      end

      def enumeration_to_classname(enumeration)
        enumeration.gwt.qualified_name
      end
    end

    class GwtException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end
    end

    class GwtApplication < Domgen.ParentedElement(:repository)
      attr_writer :package

      def package
        @package || Domgen::Naming.underscore(repository.name)
      end
    end
  end

  FacetManager.define_facet(:gwt,
                            Service => Domgen::GWT::GwtService,
                            Method => Domgen::GWT::GwtMethod,
                            Parameter => Domgen::GWT::GwtParameter,
                            Exception => Domgen::GWT::GwtException,
                            Message => Domgen::GWT::GwtEvent,
                            MessageParameter => Domgen::GWT::GwtEventParameter,
                            Exception => Domgen::GWT::GwtException,
                            Result => Domgen::GWT::GwtReturn,
                            DataModule => Domgen::GWT::GwtModule,
                            Repository => Domgen::GWT::GwtApplication)
end
