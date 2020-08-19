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
  FacetManager.facet(:redfish => [:application]) do |facet|
    facet.enhance(Repository) do
      def pre_init
        @data = Reality::Mash.new
      end

      attr_writer :custom_configuration

      def custom_configuration?
        @custom_configuration.nil? ? false : !!@custom_configuration
      end

      attr_reader :data

      def custom_resource(name, value, restype = nil, options = {})
        self.data['custom_resources'][name]['properties']['value'] = value
        self.data['custom_resources'][name]['restype'] = restype if restype
        if repository.ee? && (options[:register_jndi_constant].nil? || options[:register_jndi_constant])
          repository.ee.add_custom_jndi_resource(name)
        end
      end

      def custom_resource_from_env(name, options = {})
        env_key = nil
        if options[:system_defined]
          qualified_name = name
          env_key = options[:env_key]
          Domgen.error("redfish.custom_resource_from_env specified :system_defined => true but did not specify :env_key.") unless env_key
        else
          standard_prefix = "#{Reality::Naming.underscore(repository.name)}/env"
          Domgen.error("redfish.custom_resource_from_env specified name '#{name}' that is prefixed with '#{standard_prefix}/' which is no longer required. Remove prefix.") if name.start_with?("#{standard_prefix}/")
          Domgen.error("redfish.custom_resource_from_env specified name '#{name}' that is prefixed with '#{Reality::Naming.underscore(repository.name)}/' which is no longer supported. Remove prefix and update deployment to reflect standard prefix '#{standard_prefix}/'.") if name.start_with?("#{standard_prefix}/")
          self.custom_configuration = true
          qualified_name = "#{standard_prefix}/#{name}"
          components = qualified_name.split('/')
          components = [components.first] + components[2..components.size] if components.size > 2 && components[1] == 'env'
          env_key = components.join('_').upcase if env_key.nil?
        end
        custom_resource(qualified_name, "${#{env_key}}", options[:restype])
        environment_variable(env_key, 'UNSPECIFIED', options[:default_value])
      end

      def environment_variable(key, value = 'UNSPECIFIED', default_value = '')
        system_property(key, value)
        self.data['environment_vars'][key] = default_value
      end

      def system_property(key, value)
        Domgen.error("Redfish system_property '#{key}' can not have nil or empty value") if value.to_s == ''
        self.data['system_properties'][key] = value
      end

      def volume_requirement(key)
        self.data['volumes'][key]
      end

      def jdbc_connection_pool(name, connection_pool_name, options = {})
        db_type = options[:db_type] || (repository.mssql? ? :mssql : repository.pgsql? ? :pgsql : nil)
        application = Reality::Naming.underscore(repository.name)
        constant_prefix = Reality::Naming.uppercase_constantize(repository.name)

        cname = Reality::Naming.uppercase_constantize(name)
        prefix = cname == constant_prefix ? constant_prefix : "#{constant_prefix}_#{cname}"
        self.data['jdbc_connection_pools'][connection_pool_name]['datasourceclassname'] =
          :mssql == db_type ? 'net.sourceforge.jtds.jdbcx.JtdsDataSource' :
            :pgsql == db_type ? 'org.postgresql.ds.PGSimpleDataSource' :
              nil
        self.data['jdbc_connection_pools'][connection_pool_name]['restype'] =
          !!options[:xa_data_source] ? 'javax.sql.XADataSource' : 'javax.sql.DataSource'
        self.data['jdbc_connection_pools'][connection_pool_name]['isconnectvalidatereq'] = 'true'
        self.data['jdbc_connection_pools'][connection_pool_name]['validationmethod'] = 'auto-commit'
        self.data['jdbc_connection_pools'][connection_pool_name]['ping'] = 'true'
        self.data['jdbc_connection_pools'][connection_pool_name]['description'] = "#{name} connection pool for application #{application}"

        self.data['environment_vars']["#{prefix}_DB_HOST"] = nil
        self.data['environment_vars']["#{prefix}_DB_PORT"] = :mssql == db_type ? 1433 : :pgsql == db_type ? 5432 : nil
        self.data['environment_vars']["#{prefix}_DB_DATABASE"] = nil
        self.data['environment_vars']["#{prefix}_DB_USERNAME"] = repository.jpa? ? repository.jpa.default_username : nil
        self.data['environment_vars']["#{prefix}_DB_PASSWORD"] = nil

        self.data['jdbc_connection_pools'][connection_pool_name]['properties']['ServerName'] = "${#{prefix}_DB_HOST}"
        self.data['jdbc_connection_pools'][connection_pool_name]['properties']['User'] = "${#{prefix}_DB_USERNAME}"
        self.data['jdbc_connection_pools'][connection_pool_name]['properties']['Password'] = "${#{prefix}_DB_PASSWORD}"
        self.data['jdbc_connection_pools'][connection_pool_name]['properties']['PortNumber'] = "${#{prefix}_DB_PORT}"
        self.data['jdbc_connection_pools'][connection_pool_name]['properties']['DatabaseName'] = "${#{prefix}_DB_DATABASE}"

        if :mssql == db_type
          # Standard DataSource configuration
          self.data['jdbc_connection_pools'][connection_pool_name]['properties']['AppName'] = application
          self.data['jdbc_connection_pools'][connection_pool_name]['properties']['ProgName'] = 'GlassFish'
          self.data['jdbc_connection_pools'][connection_pool_name]['properties']['SocketTimeout'] = options[:socket_timeout] || '1200'
          self.data['jdbc_connection_pools'][connection_pool_name]['properties']['LoginTimeout'] = options[:login_timeout] || '60'
          self.data['jdbc_connection_pools'][connection_pool_name]['properties']['SocketKeepAlive'] = 'true'

          # This next lines is required for jtds drivers as still old driver style
          self.data['jdbc_connection_pools'][connection_pool_name]['properties']['jdbc30DataSource'] = 'true'
        end
      end

      def jdbc_resource(name, connection_pool_name, resource_name)
        application = Reality::Naming.underscore(repository.name)
        self.data['jdbc_connection_pools'][connection_pool_name]['resources'][resource_name]['description'] = "#{name} resource for application #{application}"
      end

      def persistence_unit(name, resource_name, options = {})
        connection_pool_name = "#{resource_name}ConnectionPool"
        jdbc_connection_pool(name, connection_pool_name,
                             :xa_data_source => options[:xa_data_source],
                             :socket_timeout => options[:socket_timeout],
                             :login_timeout => options[:login_timeout])
        jdbc_resource(name, connection_pool_name, resource_name)
      end

      def pre_complete
        key = Reality::Naming.uppercase_constantize(repository.name)

        # We magically create environment variables for any of the required settings
        # if they are used in custom_resources
        self.data['environment_vars'].keys.each do |name|
          value = self.data['environment_vars'][name].to_s

          create_env_if_required("#{key}_PUBLIC_HOST_URL", value)
          create_env_if_required("#{key}_PUBLIC_URL", value)
          create_env_if_required("#{key}_INTERNAL_URL", value)
          create_env_if_required("#{key}_INTERNAL_HOST_URL", value)
        end
      end

      private

      def create_env_if_required(env_key, value)
        if value =~ /\$\{#{env_key}\}/ && !self.data['environment_vars'].include?(env_key)
          self.environment_variable(env_key)
        end
      end
    end
  end
end
