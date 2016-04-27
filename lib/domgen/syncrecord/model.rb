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
  FacetManager.facet(:syncrecord => [:appconfig]) do |facet|
    facet.enhance(Repository) do
      attr_writer :short_test_code

      def short_test_code
        @short_test_code || 'sr'
      end

      def pre_complete
        repository.jaxrs.extensions << 'iris.syncrecord.server.rest.SyncStatusService' if repository.jaxrs?

        if repository.jpa?
          repository.jpa.persistence_file_content_fragments << <<FRAGMENT
<!-- syncrecord fragment is auto-generated -->
<persistence-unit name="SyncRecord" transaction-type="JTA">
  <jta-data-source>#{repository.jpa.data_source}</jta-data-source>

  <class>iris.syncrecord.server.entity.Synchronization</class>
  <class>iris.syncrecord.server.entity.Message</class>
  <class>iris.syncrecord.server.entity.Metric</class>

  <exclude-unlisted-classes>true</exclude-unlisted-classes>
  <shared-cache-mode>ENABLE_SELECTIVE</shared-cache-mode>
  <validation-mode>AUTO</validation-mode>

  <properties>
    <property name="eclipselink.logging.logger" value="JavaLogger"/>
    <property name="eclipselink.session-name" value="#{repository.name}SyncRecord"/>
    <property name="eclipselink.temporal.mutable" value="false"/>
  </properties>
</persistence-unit>
<!-- syncrecord fragment end -->
FRAGMENT
        end
      end
    end
  end
end
