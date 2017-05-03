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

      def pre_complete
        if repository.jpa?
          repository.jpa.application_artifact_fragments << "iris.audit#{repository.pgsql? ? '.pg' : ''}:audit-server"
        end
      end
    end
    facet.enhance(Service) do
      def pre_complete
        if service.ejb?
          service.ejb.boundary_interceptors << 'iris.audit.server.service.LoggingInterceptor'
        end
      end
    end
  end
end
