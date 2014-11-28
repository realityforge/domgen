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
    module GwtRpc
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:gwt_rpc]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end
Domgen.template_set(:gwt_rpc_shared_service) do |template_set|
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :service,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/rpc_service.java.erb",
                        'main/java/#{service.gwt_rpc.qualified_rpc_service_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :service,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/async_rpc_service.java.erb",
                        'main/java/#{service.gwt_rpc.qualified_async_rpc_service_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :exception,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/exception.java.erb",
                        'main/java/#{exception.gwt_rpc.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
end

Domgen.template_set(:gwt_rpc_client_service) do |template_set|
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :repository,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/rpc_request_builder.java.erb",
                        'main/java/#{repository.gwt_rpc.qualified_rpc_request_builder_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS,
                        :guard => 'repository.imit?')
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :repository,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/rpc_services_module.java.erb",
                        'main/java/#{repository.gwt_rpc.qualified_rpc_services_module_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :service,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/facade_service.java.erb",
                        'main/java/#{service.gwt_rpc.qualified_facade_service_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :service,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/proxy.java.erb",
                        'main/java/#{service.gwt_rpc.qualified_proxy_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
end
Domgen.template_set(:gwt_rpc_test_module) do |template_set|
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :repository,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/mock_services_module.java.erb",
                        'test/java/#{repository.gwt_rpc.qualified_mock_services_module_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
end

Domgen.template_set(:gwt_rpc_module) do |template_set|
  template_set.template(Domgen::Generator::GwtRpc::FACETS,
                        :repository,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/mock_services_module.java.erb",
                        'main/java/#{repository.gwt_rpc.qualified_mock_services_module_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
end

Domgen.template_set(:gwt_rpc_server_service) do |template_set|
  template_set.template(Domgen::Generator::GwtRpc::FACETS + [:ejb],
                        :service,
                        "#{Domgen::Generator::GwtRpc::TEMPLATE_DIRECTORY}/servlet.java.erb",
                        'main/java/#{service.gwt_rpc.qualified_servlet_name.gsub(".","/")}.java',
                        Domgen::Generator::GwtRpc::HELPERS)
end

Domgen.template_set(:gwt_rpc_shared => [:gwt_rpc_shared_service])
Domgen.template_set(:gwt_rpc_client => [:gwt_rpc_client_service, :gwt_rpc_test_module, :gwt_client_jso])
Domgen.template_set(:gwt_rpc_server => [:gwt_rpc_server_service])
Domgen.template_set(:gwt_rpc => [:gwt_rpc_shared, :gwt_rpc_client, :gwt_rpc_server])
