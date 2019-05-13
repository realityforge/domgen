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

Domgen::Generator.define([:graphql],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::Graphql::Helper]) do |g|
  g.template_set(:graphql_endpoint) do |template_set|
    template_set.erb_template(:repository,
                              'schema.graphqls.erb',
                              'main/java/#{repository.graphql.qualified_schema_name.gsub(".","/")}.graphqls')
    template_set.erb_template(:repository,
                              'abstract_schema_service.java.erb',
                              'main/java/#{repository.graphql.qualified_abstract_schema_service_name.gsub(".","/")}.java',
                              :additional_facets => [:ee])
    template_set.erb_template(:repository,
                              'endpoint.java.erb',
                              'main/java/#{repository.graphql.qualified_endpoint_name.gsub(".","/")}.java',
                              :additional_facets => [:ee],
                              :guard => '!repository.graphql.custom_endpoint?')
  end
end
