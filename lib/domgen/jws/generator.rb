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
      HELPERS = [Domgen::Java::Helper, Domgen::JWS::Helper]
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

Domgen.template_set(:jws_server_service) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.jws.qualified_java_service_name.gsub(".","/")}.java',
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
  # GlassFish 4 / EE4 requires that the files appear in META-INF which seems counter to documentation at
  # https://jax-ws.java.net/nonav/2.1.5/docs/catalog-support.html
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/wsdl.xml.erb",
                        'main/webapp/META-INF/wsdl/#{service.jws.wsdl_name}',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/jax_ws_catalog.xml.erb",
                        'main/webapp/META-INF/jax-ws-catalog.xml',
                        Domgen::Generator::JWS::HELPERS)
  # GlassFish 3.1.2.2 / EE6 requires that the files appear in WEB-INF
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/wsdl.xml.erb",
                        'main/webapp/WEB-INF/wsdl/#{service.jws.wsdl_name}',
                        Domgen::Generator::JWS::HELPERS,
                        nil,
                        :name => 'WEB-INF/wsdl.xml')
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/jax_ws_catalog.xml.erb",
                        'main/webapp/WEB-INF/jax-ws-catalog.xml',
                        Domgen::Generator::JWS::HELPERS,
                        nil,
                        :name => 'WEB-INF/jax_ws_catalog.xml')
end

Domgen.template_set(:jws_server => [:jws_server_boundary, :jws_server_service, :jws_wsdl_assets])
Domgen.template_set(:jws_client => [:jws_wsdl_resources])
Domgen.template_set(:jws => [:jws_server, :jws_client])
