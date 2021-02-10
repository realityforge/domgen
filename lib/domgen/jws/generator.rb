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

Domgen::Generator.define([:jws],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::Xml::Helper, Domgen::JAXB::Helper, Domgen::Jws::Helper]) do |g|
  g.template_set(:jws_server_boundary) do |template_set|
    template_set.erb_template(:service,
                              'boundary_implementation.java.erb',
                              'main/java/#{service.jws.qualified_boundary_implementation_name.gsub(".","/")}.java',
                              :additional_facets => [:ejb])
  end

  g.template_set(:jws_client_service) do |template_set|
    Domgen::JWS::WsimportTemplate.new(template_set,
                                      Domgen::Generator.current_facets,
                                      :service,
                                      'wsimport',
                                      '#{service.jws.api_package}',
                                      Domgen::Generator.current_helpers)
  end

  g.template_set(:jws_client_handler) do |template_set|
    template_set.erb_template(:repository,
                              'handler_resolver.java.erb',
                              'main/java/#{repository.jws.qualified_handler_resolver_name.gsub(".","/")}.java')
  end

  g.template_set(:jws_type_converter) do |template_set|
    template_set.erb_template(:service,
                              'type_converter.java.erb',
                              'main/java/#{service.jws.qualified_type_converter_name.gsub(".","/")}.java')
  end

  g.template_set(:jws_server_service) do |template_set|
    template_set.erb_template(:service,
                              'service.java.erb',
                              'main/java/#{service.jws.qualified_java_service_name.gsub(".","/")}.java')
    template_set.erb_template(:exception,
                              'exception.java.erb',
                              'main/java/#{exception.jws.qualified_name.gsub(".","/")}.java')
    template_set.erb_template(:exception,
                              'fault_info.java.erb',
                              'main/java/#{exception.jws.qualified_fault_info_name.gsub(".","/")}.java')
  end

  g.template_set(:jws_wsdl_resources) do |template_set|
    template_set.erb_template(:service,
                              'wsdl.xml.erb',
                              'main/resources/META-INF/wsdl/#{service.jws.wsdl_name}')
    template_set.erb_template(:repository,
                              'jax_ws_catalog.xml.erb',
                              'main/resources/META-INF/jax-ws-catalog.xml')
  end

  g.template_set(:jws_wsdl_assets) do |template_set|
    template_set.erb_template(:service,
                              'wsdl.xml.erb',
                              'main/webapp/WEB-INF/wsdl/#{service.jws.wsdl_name}',
                              :name => 'WEB-INF/wsdl.xml')
    template_set.erb_template(:repository,
                              'jax_ws_catalog.xml.erb',
                              'main/webapp/WEB-INF/jax-ws-catalog.xml',
                              :name => 'WEB-INF/jax_ws_catalog.xml')
  end

  g.template_set(:jws_jaxws_config) do |template_set|
    template_set.erb_template(:repository,
                              'sun_jaxws.xml.erb',
                              'main/webapp/WEB-INF/sun-jaxws.xml')
  end

  g.template_set(:jws_shared) do |template_set|
    template_set.erb_template(:repository,
                              'constants_container.java.erb',
                              'main/java/#{repository.jws.qualified_constants_container_name.gsub(".","/")}.java')
  end

  g.template_set(:jws_server => [:jws_server_boundary, :jws_server_service, :jws_wsdl_assets, :xml_xsd_assets])
  g.template_set(:jws_client => [:jws_wsdl_resources, :xml_xsd_resources, :jws_client_service, :jws_client_handler])
  g.template_set(:jws => [:jws_server, :jws_client])
end
