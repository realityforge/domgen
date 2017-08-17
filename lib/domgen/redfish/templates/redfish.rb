def define_custom_resource(data, key, value, restype = nil)
  data['custom_resources'] ||= {}
  data['custom_resources'][key]['properties']['value'] = value
  data['custom_resources'][key]['restype'] = restype if restype
end

def define_context_service(data, name, options = {})
  data['context_services'][name] = {
    'enabled' => 'true',
    'context_info_enabled' => 'true',
    'context_info' => 'Classloader,JNDI,Security,WorkArea',
    'deployment_order' => 100
  }.merge(options)
end

def generate(repository)
  application = Reality::Naming.underscore(repository.name)
  constant_prefix = Reality::Naming.uppercase_constantize(repository.name)

  data = Reality::Mash.from(repository.redfish.data.to_h)

  if repository.mail?
    data['environment_vars']["#{constant_prefix}_MAIL_HOST"] = ''
    data['environment_vars']["#{constant_prefix}_MAIL_USER"] = ''
    data['environment_vars']["#{constant_prefix}_MAIL_FROM"] = ''

    data['javamail_resources'][repository.mail.resource_name] =
      {
        'host' => "${#{constant_prefix}_MAIL_HOST}",
        'user' => "${#{constant_prefix}_MAIL_USER}",
        'from' => "${#{constant_prefix}_MAIL_FROM}"
      }
  end

  if repository.gwt_rpc? && repository.application.code_deployable?
    data['environment_vars']["#{constant_prefix}_CODE_SERVER_HOST"] = 'localhost'
    data['environment_vars']["#{constant_prefix}_CODE_SERVER_PORT"] = '0'

    define_custom_resource(data, "#{application}/env/code_server/host", "${#{constant_prefix}_CODE_SERVER_HOST}")
    define_custom_resource(data, "#{application}/env/code_server/port", "${#{constant_prefix}_CODE_SERVER_PORT}", 'java.lang.Integer')
  end

  if repository.imit?
    data['managed_scheduled_executor_services'][repository.imit.executor_service_jndi] = {
      'enabled' => 'true',
      'context_info_enabled' => 'true',
      'context_info' => 'Classloader,JNDI,Security,WorkArea',
      'deployment_order' => 100,
      'thread_priority' => 5
    }

    define_context_service(data, repository.imit.context_service_jndi)

    repository.imit.remote_datasources.each do |rd|
      prefix = "#{application}/replicant/client/#{Reality::Naming.underscore(rd.name)}"
      env_prefix = "#{constant_prefix}_REPLICANT_CLIENT_#{Reality::Naming.uppercase_constantize(rd.name)}"
      data['environment_vars']["#{env_prefix}_URL"] = ''
      data['environment_vars']["#{env_prefix}_REPOSITORYDEBUGOUTPUTENABLED"] = 'false'
      data['environment_vars']["#{env_prefix}_SUBSCRIPTIONSDEBUGOUTPUTENABLED"] = 'false'
      data['environment_vars']["#{env_prefix}_SHOULDVALIDATEREPOSITORYONLOAD"] = 'false'
      data['environment_vars']["#{env_prefix}_REQUESTDEBUGOUTPUTENABLED"] = 'false'

      define_custom_resource(data, "#{prefix}/url", "${#{env_prefix}_URL}")
      define_custom_resource(data, "#{prefix}/repositoryDebugOutputEnabled", "${#{env_prefix}_REPOSITORYDEBUGOUTPUTENABLED}", 'java.lang.Boolean')
      define_custom_resource(data, "#{prefix}/subscriptionsDebugOutputEnabled", "${#{env_prefix}_SUBSCRIPTIONSDEBUGOUTPUTENABLED}", 'java.lang.Boolean')
      define_custom_resource(data, "#{prefix}/shouldValidateRepositoryOnLoad", "${#{env_prefix}_SHOULDVALIDATEREPOSITORYONLOAD}", 'java.lang.Boolean')
      define_custom_resource(data, "#{prefix}/requestDebugOutputEnabled", "${#{env_prefix}_REQUESTDEBUGOUTPUTENABLED}", 'java.lang.Boolean')
    end
  end

  if repository.keycloak?
    repository.keycloak.clients.each do |client|
      prefix = client.jndi_config_base
      client_prefix = client.client_constant_prefix
      data['environment_vars']["#{client_prefix}_REALM"] = ''
      data['environment_vars']["#{client_prefix}_REALM_PUBLIC_KEY"] = ''
      data['environment_vars']["#{client_prefix}_SERVER_URL"] = ''
      data['environment_vars']["#{client_prefix}_CLIENT_NAME"] = ''

      define_custom_resource(data, "#{prefix}/realm", "${#{client_prefix}_REALM}")
      define_custom_resource(data, "#{prefix}/realm-public-key", "${#{client_prefix}_REALM_PUBLIC_KEY}")
      define_custom_resource(data, "#{prefix}/auth-server-url", "${#{client_prefix}_SERVER_URL}")
      define_custom_resource(data, "#{prefix}/resource", "${#{client_prefix}_CLIENT_NAME}")
    end
    repository.keycloak.remote_clients.each do |remote_client|
      prefix = remote_client.jndi_config_base
      client_prefix = remote_client.client_constant_prefix
      data['environment_vars']["#{client_prefix}_SERVER_URL"] = ''
      data['environment_vars']["#{client_prefix}_REALM"] = ''
      data['environment_vars']["#{client_prefix}_CLIENT_NAME"] = ''
      data['environment_vars']["#{client_prefix}_USERNAME"] = ''
      data['environment_vars']["#{client_prefix}_PASSWORD"] = ''

      define_custom_resource(data, "#{prefix}/server_url", "${#{client_prefix}_SERVER_URL}")
      define_custom_resource(data, "#{prefix}/realm", "${#{client_prefix}_REALM}")
      define_custom_resource(data, "#{prefix}/client", "${#{client_prefix}_CLIENT_NAME}")
      define_custom_resource(data, "#{prefix}/username", "${#{client_prefix}_USERNAME}")
      define_custom_resource(data, "#{prefix}/password", "${#{client_prefix}_PASSWORD}")
    end
  end

  if repository.jms?
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

  ::JSON.pretty_generate(data.to_h)
end
