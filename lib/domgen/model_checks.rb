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

module Domgen #nodoc
  module ModelChecks #nodoc
    class << self
      def name_check(repository)
        repository.model_check(:Names) do |mc|
          mc.check = Proc.new do |r|
            check_name('Repository', r)
            r.data_modules.each do |data_module|
              check_name('Data Module', data_module)

              data_module.enumerations.each do |enumeration|
                check_name('Enumeration', enumeration)

                #TODO: Verify enumeration_values are constant cased?
              end

              data_module.daos.each do |dao|
                check_name('Data Access Object', dao)
                dao.queries.each do |query|
                  check_name('Query', query)
                  query.parameters.each do |parameter|
                    check_name('Query Parameter', parameter)
                  end
                end
              end

              data_module.services.each do |service|
                check_name('Service', service)
                service.methods.each do |method|
                  check_name('Method', method)
                  method.parameters.each do |parameter|
                    check_name('Method Parameter', parameter)
                  end
                end
              end

              data_module.messages.each do |message|
                check_name('Message', message)
                message.parameters.each do |parameter|
                  check_name('Message Parameter', parameter)
                end
              end

              data_module.structs.each do |struct|
                check_name('Struct', struct)
                struct.fields.each do |field|
                  check_name('Field', field)
                end
              end

              data_module.exceptions.each do |exception|
                check_name('Exception', exception)
                exception.parameters.each do |parameter|
                  check_name('Exception Parameter', parameter)
                end
              end

              data_module.entities.each do |entity|
                check_name('Entity', entity)
                entity.attributes.each do |attribute|
                  check_name('Attribute', attribute)
                end
              end
            end
          end
        end
      end

      private

      def check_name(type, element)
        raise "#{type} '#{element.qualified_name}' does not follow naming convention and use pascal case name" unless Domgen::Naming.pascal_case?(element.name.to_s)
      end
    end
  end
end
