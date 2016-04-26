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
  FacetManager.facet(:appconfig) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :integration_test, :rest, :server, :appconfig, '#{repository.name}AppconfigTest'

      def pre_complete
        repository.jaxrs.extensions << 'iris.appconfig.server.rest.SystemSettingRestService' if repository.jaxrs?

        if repository.jpa?
          repository.jpa.persistence_file_content_fragments << <<FRAGMENT
<!-- appconfig fragment is auto-generated -->
<persistence-unit name="AppConfig" transaction-type="JTA">
  <jta-data-source>#{repository.jpa.data_source}</jta-data-source>

  <class>iris.appconfig.server.entity.SystemSetting</class>

  <exclude-unlisted-classes>true</exclude-unlisted-classes>
  <shared-cache-mode>ENABLE_SELECTIVE</shared-cache-mode>
  <validation-mode>AUTO</validation-mode>

  <properties>
    <property name="eclipselink.logging.logger" value="JavaLogger"/>
    <property name="eclipselink.session-name" value="#{repository.name}AppConfig"/>
    <property name="eclipselink.temporal.mutable" value="false"/>
  </properties>
</persistence-unit>
<!-- appconfig fragment end -->
FRAGMENT
        end
      end
    end
  end
end
