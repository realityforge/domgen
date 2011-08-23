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
      attr_writer :cancelable

      def cancelable?
        @cancelable.nil? ? false : @cancelable
      end
    end

    class GwtPackage < Domgen.ParentedElement(:data_module)
      attr_writer :shared_package

      def shared_package
        @shared_package || "#{data_module.java.package}.shared"
      end

      attr_writer :server_package

      def server_package
        @server_package || "#{data_module.java.package}.server"
      end
    end
  end

  FacetManager.define_facet(:gwt,
                            Service => Domgen::GWT::GwtService,
                            Method => Domgen::GWT::GwtMethod,
                            DataModule => Domgen::GWT::GwtPackage)
end
