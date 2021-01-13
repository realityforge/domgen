#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Domgen
  FacetManager.facet(:iris_audit) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :audit_resources, :service, :server, :iris_audit, '#{repository.name}JeeAuditResources'
      java_artifact :audit_context_impl, :service, :server, :iris_audit, '#{repository.name}AuditContextImpl'
      java_artifact :audit_context_util, :service, :server, :iris_audit, '#{repository.name}AuditContextHolder'
      java_artifact :audit_fragment_adapter, :ioc, :client, :iris_audit, '#{repository.name}ToAuditFragment'

      def client_ioc_package
        repository.gwt.client_ioc_package
      end

      def pre_complete
        if repository.jpa?
          repository.jpa.application_artifact_fragments << "iris.audit#{repository.pgsql? ? '.pg' : ''}:audit-server"
        end
        if repository.redfish?
          resource_name = "#{Reality::Naming.underscore(repository.name)}/jdbc/Audit"
          repository.redfish.persistence_unit('Audit', resource_name)
        end
        if repository.gwt?
          if repository.application.user_experience?
            repository.gwt.sting_includes << 'iris.audit.client.ioc.AuditFragment'
            repository.gwt.sting_includes << qualified_audit_fragment_adapter_name
            repository.gwt.sting_test_includes << 'iris.audit.client.test.util.MockAuditGwtRpcServicesFragment'
          else
            repository.gwt.sting_test_injector_includes << 'iris.audit.client.test.util.MockAuditGwtRpcServicesFragment'
          end
        end
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :interceptor_impl, :service, :server, :iris_audit, '#{service.name}LoggingInterceptor', :sub_package => 'internal'

      def post_verify
        service.disable_facet(:iris_audit) unless service.methods.any?{|m| m.iris_audit?}
        if service.iris_audit? && (!service.ejb? || !service.ejb.generate_boundary?)
          Domgen::error("Service #{service.qualified_name} has iris_audit facet enabled but has no associated ejb boundary so no boundary will be enabled")
        end
      end
    end

    facet.enhance(Method) do
      include Domgen::Java::BaseJavaGenerator

      def pre_complete
        if method.service.ejb? && method.service.ejb.generate_boundary?
          method.ejb.boundary_interceptors << method.service.iris_audit.qualified_interceptor_impl_name
        end
      end
    end
  end
end
