def define_custom_resource(data, key, value, restype = nil)
  data['custom_resources'] ||= {}
  data['custom_resources'][key] = {}
  data['custom_resources'][key]['properties'] = {}
  data['custom_resources'][key]['properties']['value'] = value
  data['custom_resources'][key]['restype'] = restype if restype
end

def define_persistence_unit(data, repository, name, resource, options = {})
  application = Reality::Naming.underscore(repository.name)
  constant_prefix = Reality::Naming.uppercase_constantize(repository.name)

  cname = Reality::Naming.uppercase_constantize(name)
  prefix = cname == constant_prefix ? constant_prefix : "#{constant_prefix}_#{cname}"
  connection_pool = "#{resource}ConnectionPool"

  data['jdbc_connection_pools'][connection_pool] = {}
  data['jdbc_connection_pools'][connection_pool]['datasourceclassname'] =
    repository.mssql? ? 'net.sourceforge.jtds.jdbcx.JtdsDataSource' :
      repository.pgsql? ? 'org.postgresql.ds.PGSimpleDataSource' :
        nil
  data['jdbc_connection_pools'][connection_pool]['restype'] =
    !!options[:xa_data_source] ? 'javax.sql.XADataSource' : 'javax.sql.DataSource'
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
    data['jdbc_connection_pools'][connection_pool]['properties']['SocketTimeout'] = options[:socket_timeout] || '1200'
    data['jdbc_connection_pools'][connection_pool]['properties']['LoginTimeout'] = options[:login_timeout] || '60'
    data['jdbc_connection_pools'][connection_pool]['properties']['SocketKeepAlive'] = 'true'

    # This next lines is required for jtds drivers as still old driver style
    data['jdbc_connection_pools'][connection_pool]['properties']['jdbc30DataSource'] = 'true'
  end
end

def generate(repository)
  application = Reality::Naming.underscore(repository.name)
  constant_prefix = Reality::Naming.uppercase_constantize(repository.name)

  data = {}

  data['environment_vars'] = {}

  if repository.mail?
    data['environment_vars']["#{constant_prefix}_MAIL_HOST"] = ''
    data['environment_vars']["#{constant_prefix}_MAIL_USER"] = ''
    data['environment_vars']["#{constant_prefix}_MAIL_FROM"] = ''

    data['javamail_resources'] = {}

    data['javamail_resources'][repository.mail.resource_name] =
      {
        'host' => "${#{constant_prefix}_MAIL_HOST}",
        'user' => "${#{constant_prefix}_MAIL_USER}",
        'from' => "${#{constant_prefix}_MAIL_FROM}"
      }
  end

  if repository.imit?
    data['managed_scheduled_executor_services'] = {}

    data['managed_scheduled_executor_services'][repository.imit.executor_service_jndi] = {
      'enabled' => 'true',
      'context_info_enabled' => 'true',
      'context_info' => 'Classloader,JNDI,Security,WorkArea',
      'deployment_order' => 100,
      'thread_priority' => 5
    }

    data['context_services'] = {}

    data['context_services'][repository.imit.context_service_jndi] = {
      'enabled' => 'true',
      'context_info_enabled' => 'true',
      'context_info' => 'Classloader,JNDI,Security,WorkArea',
      'deployment_order' => 100
    }
  end

  if repository.keycloak?
    repository.keycloak.clients.each do |client|
      prefix = client.jndi_config_base
      client_prefix = client.client_constant_prefix
      data['environment_vars']["#{client_prefix}_KEYCLOAK_REALM"] = ''
      data['environment_vars']["#{client_prefix}_KEYCLOAK_REALM_PUBLIC_KEY"] = ''
      data['environment_vars']["#{client_prefix}_KEYCLOAK_AUTH_SERVER_URL"] = ''
      data['environment_vars']["#{client_prefix}_KEYCLOAK_CLIENT_NAME"] = ''

      define_custom_resource(data, "#{prefix}/realm", "${#{client_prefix}_KEYCLOAK_REALM}")
      define_custom_resource(data, "#{prefix}/realm-public-key", "${#{client_prefix}_KEYCLOAK_REALM_PUBLIC_KEY}")
      define_custom_resource(data, "#{prefix}/auth-server-url", "${#{client_prefix}_KEYCLOAK_AUTH_SERVER_URL}")
      define_custom_resource(data, "#{prefix}/resource", "${#{client_prefix}_KEYCLOAK_CLIENT_NAME}")
    end
  end

  if repository.jms?
    data['jms_resources'] = {}

    repository.jms.destinations.each do |destination|
      data['jms_resources'][destination.resource_name] = { 'restype' => destination.destination_type, 'properties' => { 'Name' => destination.physical_name } }
    end

    data['environment_vars']["#{constant_prefix}_BROKER_USERNAME"] = repository.jms.default_username
    data['environment_vars']["#{constant_prefix}_BROKER_PASSWORD"] = ''

    data['jms_resources'][repository.jms.connection_factory_resource_name] =
      {
        'restype' => 'javax.jms.ConnectionFactory',
        'properties' => repository.jms.additional_connection_factory_properties.merge(
          'UserName' => "${#{constant_prefix}_BROKER_USERNAME}",
          'Password' => "${#{constant_prefix}_BROKER_PASSWORD}"
        )
      }
  end

  if repository.jpa?
    units = repository.jpa.persistence_units

    data['jdbc_connection_pools'] = {}
    units.each do |unit|
      define_persistence_unit(data,
                              repository,
                              unit.short_name,
                              unit.resolved_data_source,
                              :xa_data_source => unit.xa_data_source?,
                              :socket_timeout => unit.socket_timeout,
                              :login_timeout => unit.login_timeout)

      unit.related_database_keys.each do |key|
        env_key = "#{Reality::Naming.uppercase_constantize(repository.name)}_#{repository.name == unit.short_name ? '' : "#{unit.short_name}_"}#{Reality::Naming.uppercase_constantize(key)}_DATABASE_NAME"
        data['environment_vars'][env_key] = ''
        define_custom_resource(data, unit.related_database_jndi(key), "${#{env_key}}")
      end
    end
  end

  ::JSON.pretty_generate(data)
end
