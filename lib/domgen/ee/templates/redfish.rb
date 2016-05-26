def generate(repository)
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

  data['jms_resources'][repository.jms.connection_factory_resource_name] = {'restype' => 'javax.jms.ConnectionFactory'}

  ::JSON.pretty_generate(data)
end
