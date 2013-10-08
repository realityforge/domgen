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

Domgen.template_set(:jws_server_code) do |template_set|
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :service,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/boundary_implementation.java.erb",
                        'main/java/#{service.jws.qualified_boundary_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::JWS::HELPERS)
end

Domgen.template_set(:jws_wsdl) do |template_set|
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
                        'main/webapp/META-INF/wsdl/#{service.jws.wsdl_name}',
                        Domgen::Generator::JWS::HELPERS)
  template_set.template(Domgen::Generator::JWS::FACETS,
                        :repository,
                        "#{Domgen::Generator::JWS::TEMPLATE_DIRECTORY}/jax_ws_catalog.xml.erb",
                        'main/webapp/META-INF/jax-ws-catalog.xml',
                        Domgen::Generator::JWS::HELPERS)
end

Domgen.template_set(:jws_server => [:jws_server_code, :jws_wsdl_assets])
Domgen.template_set(:jws_client => [:jws_wsdl_resources])
Domgen.template_set(:jws => [:jws_server, :jws_client])
