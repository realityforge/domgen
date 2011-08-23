module Domgen
  module GWT
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
        "#{service.data_module.repository.gwt.shared_package}.#{service_name}"
      end

      def async_service_name
        "#{service_name}Async"
      end

      def qualified_async_service_name
        "#{service.data_module.repository.gwt.shared_package}.#{async_service_name}"
      end

      def servlet_name
        @servlet_name || "#{service_name}Servlet"
      end

      def qualified_servlet_name
        "#{service.data_module.repository.gwt.server_package}.#{servlet_name}"
      end
    end

    class GwtMethod < Domgen.ParentedElement(:method)
      attr_writer :cancelable

      def cancelable?
        @cancelable.nil? ? false : @cancelable
      end
    end

    class GwtModule < Domgen.ParentedElement(:repository)
      attr_writer :module_name

      def module_name
        @module_name || repository.name
      end

      attr_writer :package

      def package
        @package || repository.java.package
      end

      attr_writer :shared_package

      def shared_package
        @shared_package || "#{package}.shared"
      end

      attr_writer :client_package

      def client_package
        @client_package || "#{package}.client"
      end

      attr_writer :server_package

      def server_package
        @server_package || "#{package}.server"
      end

      attr_writer :gin_module_name

      def gin_module_name
        @gin_module_name || "#{module_name}ServicesGinModule"
      end

      def qualified_gin_module_name
        "#{client_package}.#{gin_module_name}"
      end
    end
  end

  FacetManager.define_facet(:gwt,
                            Service => Domgen::GWT::GwtService,
                            Method => Domgen::GWT::GwtMethod,
                            Repository => Domgen::GWT::GwtModule)
end
