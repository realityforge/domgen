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
                         [Domgen::Java::Helper]) do |g|
  g.template_set(:graphql_schema) do |template_set|
    template_set.erb_template(:repository,
                              'graphql_schema.graphql.erb',
                              'main/resources/#{repository.graphql.graphql_schema_name}.graphql')
  end

  g.template_set(:graphql_resolvers) do |template_set|
    template_set.erb_template(:entity,
                              'resolver.java.erb',
                              'main/java/#{entity.graphql.qualified_resolver_name.gsub(".","/")}.java',
                              :additional_facets => [:jpa],
                              :guard => '!entity.abstract?')
    template_set.erb_template(:struct,
                              'struct_resolver.java.erb',
                              'main/java/#{struct.graphql.qualified_struct_resolver_name.gsub(".","/")}.java',
                              :additional_facets => [:ee])
  end

  g.template_set(:graphql_endpoint) do |template_set|
    template_set.erb_template(:repository,
                              'abstract_endpoint.java.erb',
                              'main/java/#{repository.graphql.qualified_abstract_endpoint_name.gsub(".","/")}.java',
                              :additional_facets => [:ee])
  end
end
