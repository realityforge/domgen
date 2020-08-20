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
    data['environment_vars']["#{constant_prefix}_CODE_SERVER_HOST"] = '127.0.0.1'
    data['environment_vars']["#{constant_prefix}_CODE_SERVER_PORT"] = '0'

    define_custom_resource(data, "#{application}/env/code_server/host", "${#{constant_prefix}_CODE_SERVER_HOST}")
    define_custom_resource(data, "#{application}/env/code_server/port", "${#{constant_prefix}_CODE_SERVER_PORT}", 'java.lang.Integer')
  end

  if repository.graphql?
    define_context_service(data, repository.graphql.context_service_jndi_name)
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
