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

Domgen::Generator.define([:action],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:action_server) do |template_set|
    template_set.erb_template(:service,
                              'service_actions.java.erb',
                              'main/java/#{service.action.qualified_service_actions_name.gsub(".","/")}.java')
    template_set.erb_template(:method,
                              'serverside_action.java.erb',
                              'main/java/#{method.action.qualified_method_actions_name.gsub(".","/")}.java',
                              :guard => 'method.action.generate_serverside_action?')
    template_set.erb_template(:exception,
                              'exception_json_encoder.java.erb',
                              'main/java/#{exception.action.qualified_json_encoder_name.gsub(".","/")}.java')
    template_set.erb_template(:struct,
                              'struct_json_encoder.java.erb',
                              'main/java/#{struct.action.qualified_json_encoder_name.gsub(".","/")}.java')
  end

  g.template_set(:action_types_mssql) do |template_set|
    template_set.erb_template(:repository,
                              'action_type_populator.sql.erb',
                              'db-hooks/post/#{repository.name}_ActionTypesPopulator.sql')
  end
end
