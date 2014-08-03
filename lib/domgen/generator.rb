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
    def self.generate(repository, directory, templates, filter, unprocessed_files)

      Logger.debug "Templates to process: #{templates.collect{|t|t.name}.inspect}"

      templates.each do |template|
        Logger.debug "Evaluating template: #{template.name}"
        if :repository == template.scope
          if template.applicable?(repository) && (filter.nil? || filter.call(:repository, repository))
            template.generate(directory, :repository, repository, unprocessed_files)
          end
        else
          repository.data_modules.each do |data_module|
            if :data_module == template.scope
              if template.applicable?(data_module) && (filter.nil? || filter.call(:data_module, data_module))
                template.generate(directory, :data_module, data_module, unprocessed_files)
              end
            else
              if :entity == template.scope
                data_module.entities.each do |entity|
                  if template.applicable?(entity) && (filter.nil? || filter.call(:entity, entity))
                    template.generate(directory, :entity, entity, unprocessed_files)
                  end
                end
              end

              if :dao == template.scope
                data_module.daos.each do |dao|
                  if template.applicable?(dao) && (filter.nil? || filter.call(:dao, dao))
                    template.generate(directory, :dao, dao, unprocessed_files)
                  end
                end
              end

              if :query == template.scope
                data_module.daos.each do |entity|
                  entity.queries.each do |query|
                    if template.applicable?(query) && (filter.nil? || filter.call(:query, query))
                      template.generate(directory, :query, query, unprocessed_files)
                    end
                  end
                end
              end

              if :struct == template.scope
                data_module.structs.each do |struct|
                  if template.applicable?(struct) && (filter.nil? || filter.call(:struct, struct))
                    template.generate(directory, :struct, struct, unprocessed_files)
                  end
                end
              end

              if :enumeration == template.scope
                data_module.enumerations.each do |entity|
                  if template.applicable?(entity) && (filter.nil? || filter.call(:enumeration, entity))
                    template.generate(directory, :enumeration, entity, unprocessed_files)
                  end
                end
              end

              if :exception == template.scope
                data_module.exceptions.each do |entity|
                  if template.applicable?(entity) && (filter.nil? || filter.call(:exception, entity))
                    template.generate(directory, :exception, entity, unprocessed_files)
                  end
                end
              end

              if :service == template.scope
                data_module.services.each do |service|
                  if template.applicable?(service) && (filter.nil? || filter.call(:service, service))
                    template.generate(directory, :service, service, unprocessed_files)
                  end
                end
              end

              if :method == template.scope
                data_module.services.each do |service|
                  service.methods.each do |method|
                    if template.applicable?(method) && (filter.nil? || filter.call(:method, method))
                      template.generate(directory, :method, method, unprocessed_files)
                    end
                  end
                end
              end

              if :message == template.scope
                data_module.messages.each do |message|
                  if template.applicable?(message) && (filter.nil? || filter.call(:message, message))
                    template.generate(directory, :message, message, unprocessed_files)
                  end
                end
              end
            end
          end
        end
      end
      Logger.info "Generator completed"
    end

    class GeneratorError < StandardError
      attr_reader :cause

      def initialize(message, cause = nil)
        super(message)
        @cause = cause
      end
    end
  end
end
