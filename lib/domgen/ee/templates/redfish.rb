def define_custom_resource(data, key, value)
    data['custom_resources'] ||= {}
    data['custom_resources'][key] = {}
    data['custom_resources'][key]['properties'] = {}
    data['custom_resources'][key]['properties']['value'] = value
end

def generate(repository)
  application = Domgen::Naming.underscore(repository.name)
  constant_prefix = Domgen::Naming.uppercase_constantize(repository.name)

  data = {}

  data['environment_vars'] = {}

  if repository.keycloak?
    prefix = repository.keycloak.jndi_config_base
    data['environment_vars']["#{constant_prefix}_KEYCLOAK_REALM"] = ''
    data['environment_vars']["#{constant_prefix}_KEYCLOAK_REALM_PUBLIC_KEY"] = ''
    data['environment_vars']["#{constant_prefix}_KEYCLOAK_AUTH_SERVER_URL"] = ''

    define_custom_resource(data, "#{prefix}/realm", "${#{constant_prefix}_KEYCLOAK_REALM}")
    define_custom_resource(data, "#{prefix}/realm-public-key", "${#{constant_prefix}_KEYCLOAK_REALM_PUBLIC_KEY}")
    define_custom_resource(data, "#{prefix}/auth-server-url", "${#{constant_prefix}_KEYCLOAK_AUTH_SERVER_URL}")
    define_custom_resource(data, "#{prefix}/ssl-required", 'external')
    define_custom_resource(data, "#{prefix}/resource", repository.name)
    define_custom_resource(data, "#{prefix}/public-client", true)
  end

  if repository.jms?
    data['jms_resources'] = {}

    destinations = {}

    repository.jms.endpoint_methods.each do |method|
      destinations[method.jms.destination_resource_name] = {'type' => method.jms.destination_type, 'physical_name' => method.jms.physical_resource_name}
    end
    repository.jms.router_methods.each do |method|
      destinations[method.jms.route_to_destination_resource_name] =
        {'type' => method.jms.route_to_destination_type, 'physical_name' => method.jms.route_to_physical_resource_name}
    end

    destinations.each_pair do |name, config|
      data['jms_resources'][name] = {'restype' => config['type'], 'properties' => {'Name' => config['physical_name']}}
    end

    data['environment_vars']["#{constant_prefix}_BROKER_USERNAME"] = repository.jms.default_username
    data['environment_vars']["#{constant_prefix}_BROKER_PASSWORD"] = ''

    data['jms_resources'][repository.jms.connection_factory_resource_name] =
      {
        'restype' => 'javax.jms.ConnectionFactory',
        'properties' => {
          'UserName' => "${#{constant_prefix}_BROKER_USERNAME}",
          'Password' => "${#{constant_prefix}_BROKER_PASSWORD}"
        }
      }
  end

  if repository.jpa?
    units = []
    if repository.jpa.include_default_unit? && repository.jpa.standalone?
      units << repository.jpa.default_persistence_unit
    end
    units += repository.jpa.standalone_persistence_units

    data['jdbc_connection_pools'] = {}
    units.each do |unit|
      name = unit.short_name
      cname = Domgen::Naming.uppercase_constantize(name)
      prefix = cname == constant_prefix ? constant_prefix : "#{constant_prefix}_#{cname}"
      resource = unit.data_source
      connection_pool = "#{resource}ConnectionPool"

      data['jdbc_connection_pools'][connection_pool] = {}
      data['jdbc_connection_pools'][connection_pool]['datasourceclassname'] =
        repository.mssql? ? 'net.sourceforge.jtds.jdbcx.JtdsDataSource' :
          repository.pgsql? ? 'org.postgresql.ds.PGSimpleDataSource' :
            nil
      data['jdbc_connection_pools'][connection_pool]['restype'] =
        unit.xa_data_source? ? 'javax.sql.XADataSource' : 'javax.sql.DataSource'
      data['jdbc_connection_pools'][connection_pool]['isconnectvalidatereq'] = 'true'
      data['jdbc_connection_pools'][connection_pool]['validationmethod'] = 'auto-commit'
      data['jdbc_connection_pools'][connection_pool]['ping'] = 'true'
      data['jdbc_connection_pools'][connection_pool]['description'] = "#{name} connection pool for application #{application}"

      data['jdbc_connection_pools'][connection_pool]['properties'] = {}

      data['jdbc_connection_pools'][connection_pool]['resources'] = {}
      data['jdbc_connection_pools'][connection_pool]['resources'][resource] = {}
      data['jdbc_connection_pools'][connection_pool]['resources'][resource]['description'] = "#{name} resource for application #{application}"

      data['environment_vars']["#{prefix}_DB_HOST"] = nil
      data['environment_vars']["#{prefix}_DB_PORT"] = repository.mssql? ? 1433 : repository.pgsql? ? 5432 : nil
      data['environment_vars']["#{prefix}_DB_DATABASE"] = nil
      data['environment_vars']["#{prefix}_DB_USERNAME"] = repository.jpa.default_username
      data['environment_vars']["#{prefix}_DB_PASSWORD"] = nil

      data['jdbc_connection_pools'][connection_pool]['properties']['ServerName'] = "${#{prefix}_DB_HOST}"
      data['jdbc_connection_pools'][connection_pool]['properties']['User'] = "${#{prefix}_DB_USERNAME}"
      data['jdbc_connection_pools'][connection_pool]['properties']['Password'] = "${#{prefix}_DB_PASSWORD}"
      data['jdbc_connection_pools'][connection_pool]['properties']['PortNumber'] = "${#{prefix}_DB_PORT}"
      data['jdbc_connection_pools'][connection_pool]['properties']['DatabaseName'] = "${#{prefix}_DB_DATABASE}"

      if repository.mssql?
        # Standard DataSource configuration
        data['jdbc_connection_pools'][connection_pool]['properties']['AppName'] = application
        data['jdbc_connection_pools'][connection_pool]['properties']['ProgName'] = 'GlassFish'
        data['jdbc_connection_pools'][connection_pool]['properties']['SocketTimeout'] = unit.socket_timeout
        data['jdbc_connection_pools'][connection_pool]['properties']['LoginTimeout'] = unit.login_timeout
        data['jdbc_connection_pools'][connection_pool]['properties']['SocketKeepAlive'] = 'true'

        # This next lines is required for jtds drivers as still old driver style
        data['jdbc_connection_pools'][connection_pool]['properties']['jdbc30DataSource'] = 'true'
      end
    end
  end

  ::JSON.pretty_generate(data)
end
