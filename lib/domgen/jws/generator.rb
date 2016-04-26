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
  module Generator
    module JWS
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jws]
      HELPERS = [Domgen::Java::Helper, Domgen::Xml::Helper, Domgen::JAXB::Helper]
    end
  end
end

Domgen.template_set(:jws_server_boundary) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/boundary_implementation.java.erb",
                        'main/java/#{service.jws.qualified_boundary_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
end

Domgen.template_set(:jws_client_service) do |template_set|
  template = Domgen::JWS::WsimportTemplate.new(template_set,
                                               Domgen::Generator::JWS::FACETS,
                                               :service,
                                               'wsimport',
                                               '#{service.jws.api_package}',
                                               Domgen::Generator::JWS::HELPERS)
  template_set.register_template(template)
end

Domgen.template_set(:jws_server_service) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.jws.qualified_java_service_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :exception,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/exception.java.erb",
                        'main/java/#{exception.jws.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :exception,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/fault_info.java.erb",
                        'main/java/#{exception.jws.qualified_fault_info_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
end

Domgen.template_set(:jws_wsdl_resources) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/wsdl.xml.erb",
                        'main/resources/META-INF/wsdl/#{service.jws.wsdl_name}',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/jax_ws_catalog.xml.erb",
                        'main/resources/META-INF/jax-ws-catalog.xml',
                        Domgen::Generator::JWS::HELPERS)
end

Domgen.template_set(:jws_wsdl_assets) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/wsdl.xml.erb",
                        'main/webapp/WEB-INF/wsdl/#{service.jws.wsdl_name}',
                        Domgen::Generator::JWS::HELPERS,
                        :name => 'WEB-INF/wsdl.xml')
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/jax_ws_catalog.xml.erb",
                        'main/webapp/WEB-INF/jax-ws-catalog.xml',
                        Domgen::Generator::JWS::HELPERS,
                        :name => 'WEB-INF/jax_ws_catalog.xml')
end

Domgen.template_set(:jws_jaxws_config) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/sun_jaxws.xml.erb",
                        'main/webapp/WEB-INF/sun-jaxws.xml',
                        Domgen::Generator::JWS::HELPERS)
end

Domgen.template_set(:jws_fakes) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/fake_implementation.java.erb",
                        'main/java/#{service.jws.qualified_fake_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/fake_server.java.erb",
                        'main/java/#{repository.jws.qualified_fake_server_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/fake_server_factory.java.erb",
                        'main/java/#{repository.jws.qualified_fake_server_factory_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/abstract_fake_server_test.java.erb",
                        'test/java/#{repository.jws.qualified_abstract_fake_server_test_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/client_integration_test.java.erb",
                        'test/java/#{repository.jws.qualified_client_integration_test_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
end

Domgen.template_set(:jws_server => [:jws_server_boundary, :jws_server_service, :jws_wsdl_assets, :xml_xsd_assets])
Domgen.template_set(:jws_fake_server => [:jws_fakes, :jws_server_service, :jws_wsdl_resources, :xml_xsd_resources])
Domgen.template_set(:jws_client => [:jws_wsdl_resources, :xml_xsd_resources, :jws_client_service])
Domgen.template_set(:jws => [:jws_server, :jws_client])
