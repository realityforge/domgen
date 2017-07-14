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

      def pre_complete
        if repository.jpa?
          repository.jpa.application_artifact_fragments << "iris.audit#{repository.pgsql? ? '.pg' : ''}:audit-server"
        end
        if repository.redfish?
          resource_name = "#{Reality::Naming.underscore(repository.name)}/jdbc/Audit"
          repository.redfish.persistence_unit('Audit', resource_name)
        end
      end
    end

    facet.enhance(DataModule) do
      include Domgen::Java::EEClientServerJavaPackage
    end

    facet.enhance(Service) do
      include Domgen::Java::BaseJavaGenerator

      java_artifact :interceptor_impl, :service, :server, :iris_audit, '#{service.name}LoggingInterceptor', :sub_package => 'internal'

      def pre_complete
        if service.ejb? && service.ejb.generate_boundary?
          service.ejb.boundary_interceptors << self.qualified_interceptor_impl_name
        end
      end
    end
  end
end
