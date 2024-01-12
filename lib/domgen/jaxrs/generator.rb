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

Domgen::Generator.define([:jaxrs],
                         "#{File.dirname(__FILE__)}/templates",
                         [Domgen::Java::Helper, Domgen::JaxRS::Helper]) do |g|
  g.template_set(:jaxrs) do |template_set|
    template_set.erb_template(:exception,
                              'exception_mapper.java.erb',
                              'main/java/#{exception.jaxrs.qualified_exception_mapper_name.gsub(".","/")}.java',
                              :guard => 'exception.concrete?')
    template_set.erb_template(:repository,
                              'abstract_application.java.erb',
                              'main/java/#{repository.jaxrs.qualified_abstract_application_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'constants.java.erb',
                              'main/java/#{repository.jaxrs.qualified_constants_name.gsub(".","/")}.java')
    template_set.erb_template(:repository,
                              'standard_application.java.erb',
                              'main/java/#{repository.jaxrs.qualified_standard_application_name.gsub(".","/")}.java',
                              :guard => '!repository.jaxrs.custom_application?')
    template_set.erb_template(:service,
                              'service.java.erb',
                              'main/java/#{service.jaxrs.qualified_service_name.gsub(".","/")}.java')
    template_set.erb_template(:service,
                              'boundary.java.erb',
                              'main/java/#{service.jaxrs.qualified_boundary_name.gsub(".","/")}.java')
  end
end
