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
    module GWT
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:gwt]
      HELPERS = [Domgen::Java::Helper]
    end
  end
end

Domgen.template_set(:gwt_client_event) do |template_set|
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :message,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/event.java.erb",
                        'main/java/#{message.gwt.qualified_event_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
end

Domgen.template_set(:gwt_client_jso) do |template_set|
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :enumeration,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/enumeration.java.erb",
                        'main/java/#{enumeration.gwt.qualified_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS + [:json],
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/struct.java.erb",
                        'main/java/#{struct.gwt.qualified_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS,
                        :guard => 'struct.gwt.generate_overlay?')
  template_set.template(Domgen::Generator::GWT::FACETS + [:json],
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/struct_factory.java.erb",
                        'main/java/#{struct.gwt.qualified_factory_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS,
                        :guard => 'struct.gwt.generate_overlay?')
  template_set.template(Domgen::Generator::GWT::FACETS + [:json],
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/jso_struct.java.erb",
                        'main/java/#{struct.gwt.qualified_jso_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS,
                        :guard => 'struct.gwt.generate_overlay?')
  template_set.template(Domgen::Generator::GWT::FACETS + [:json],
                        :struct,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/java_struct.java.erb",
                        'main/java/#{struct.gwt.qualified_java_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS,
                        :guard => 'struct.gwt.generate_overlay?')
end

Domgen.template_set(:gwt_client_callback) do |template_set|
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :repository,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/async_callback.java.erb",
                        'main/java/#{repository.gwt.qualified_async_callback_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
  template_set.template(Domgen::Generator::GWT::FACETS,
                        :repository,
                        "#{Domgen::Generator::GWT::TEMPLATE_DIRECTORY}/async_error_callback.java.erb",
                        'main/java/#{repository.gwt.qualified_async_error_callback_name.gsub(".","/")}.java',
                        Domgen::Generator::GWT::HELPERS)
end

Domgen.template_set(:gwt_client => [:gwt_client_event, :gwt_client_jso, :gwt_client_callback])
Domgen.template_set(:gwt => [:gwt_client])
