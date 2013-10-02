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
    module EJB
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ejb]
      HELPERS = [Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:ejb_services) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/service.java.erb",
                        'main/java/#{service.ejb.qualified_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS)
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :data_module,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/service_package_info.java.erb",
                        'main/java/#{data_module.ejb.service_package.gsub(".","/")}/package-info.java',
                        [],
                        'data_module.services.any?{|e|e.ejb?}')
end
Domgen.template_set(:ejb_service_facades => [:ejb_services]) do |template_set|
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_service.java.erb",
                        'main/java/#{service.ejb.qualified_boundary_interface_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/remote_service.java.erb",
                        'main/java/#{service.ejb.qualified_remote_service_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary? && service.ejb.remote?')
  template_set.template(Domgen::Generator::EJB::FACETS,
                        :service,
                        "#{Domgen::Generator::EJB::TEMPLATE_DIRECTORY}/boundary_implementation.java.erb",
                        'main/java/#{service.ejb.qualified_boundary_implementation_name.gsub(".","/")}.java',
                        Domgen::Generator::EJB::HELPERS,
                        'service.ejb.generate_boundary?')
end

Domgen.template_set(:ejb => [:ejb_service_facades, :jpa_ejb_dao])
