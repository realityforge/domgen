def generate(repository)
  constant_prefix = Domgen::Naming.uppercase_constantize(repository.name)

  data = {}
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
  end

  data['environment_vars'] =
    {
      "#{constant_prefix}_BROKER_USERNAME" => repository.jms.default_username,
      "#{constant_prefix}_BROKER_PASSWORD" => ''
    }

  data['jms_resources'][repository.jms.connection_factory_resource_name] =
    {
      'restype' => 'javax.jms.ConnectionFactory',
      'properties' => {
        'UserName' => "${#{constant_prefix}_BROKER_USERNAME}",
        'Password' => "${#{constant_prefix}_BROKER_PASSWORD}"
      }
    }

  ::JSON.pretty_generate(data)
end
