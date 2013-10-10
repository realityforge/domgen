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
    def self.generate(repository, directory, templates, filter)

      Logger.debug "Templates to process: #{templates.collect{|t|t.name}.inspect}"

      templates.each do |template|
        Logger.debug "Evaluating template: #{template.name}"
        if :repository == template.scope
          if template.applicable?(repository) && (filter.nil? || filter.call(:repository, repository))
            render(directory, template, :repository, repository)
          end
        else
          repository.data_modules.each do |data_module|
            if :data_module == template.scope
              if template.applicable?(data_module) && (filter.nil? || filter.call(:data_module, data_module))
                render(directory, template, :data_module, data_module)
              end
            else
              if :entity == template.scope
                data_module.entities.each do |entity|
                  if template.applicable?(entity) && (filter.nil? || filter.call(:entity, entity))
                    render(directory, template, :entity, entity)
                  end
                end
              end

              if :query == template.scope
                data_module.entities.each do |entity|
                  entity.queries.each do |query|
                    if template.applicable?(query) && (filter.nil? || filter.call(:query, query))
                      render(directory, template, :query, query)
                    end
                  end
                end
              end

              if :struct == template.scope
                data_module.structs.each do |struct|
                  if template.applicable?(struct) && (filter.nil? || filter.call(:struct, struct))
                    render(directory, template, :struct, struct)
                  end
                end
              end

              if :enumeration == template.scope
                data_module.enumerations.each do |entity|
                  if template.applicable?(entity) && (filter.nil? || filter.call(:enumeration, entity))
                    render(directory, template, :enumeration, entity)
                  end
                end
              end

              if :exception == template.scope
                data_module.exceptions.each do |entity|
                  if template.applicable?(entity) && (filter.nil? || filter.call(:exception, entity))
                    render(directory, template, :exception, entity)
                  end
                end
              end

              if :service == template.scope
                data_module.services.each do |service|
                  if template.applicable?(service) && (filter.nil? || filter.call(:service, service))
                    render(directory, template, :service, service)
                  end
                end
              end

              if :method == template.scope
                data_module.services.each do |service|
                  service.methods.each do |method|
                    if template.applicable?(method) && (filter.nil? || filter.call(:method, method))
                      render(directory, template, :method, method)
                    end
                  end
                end
              end

              if :message == template.scope
                data_module.messages.each do |message|
                  if template.applicable?(message) && (filter.nil? || filter.call(:message, message))
                    render(directory, template, :message, message)
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

      def initialize(message, cause)
        super(message)
        @cause = cause
      end
    end

    private

    def self.create_context(template, key, value)
      context = RenderContext.new
      context.set_local_variable(key, value)
      template.helpers.each do |helper|
        context.add_helper(helper)
      end
      context
    end

    def self.render(target_basedir, template, key, value, &block)
      object_name = value.respond_to?(:qualified_name) ? value.qualified_name : value.name
      Logger.debug "Generating #{template.name} for #{key} #{object_name}"

      render_context = create_context(template, key, value)
      context_binding = render_context.context_binding
      return nil if !template.guard.nil? && !eval(template.guard, context_binding,"#{template.template_filename}#Guard")
      begin
        output_filename = eval("\"#{template.output_filename_pattern}\"", context_binding, "#{template.template_filename}#Filename")
        output_filename = File.join(target_basedir, output_filename)
        result = template.render_to_string(context_binding)
        FileUtils.mkdir_p File.dirname(output_filename) unless File.directory?(File.dirname(output_filename))
        if File.exist?(output_filename) && IO.read(output_filename) == result
          Logger.debug "Skipped generation of #{template.name} for #{key} #{object_name} to #{output_filename} due to no changes"
        else
          File.open(output_filename, 'w') { |f| f.write(result) }
          Logger.debug "Generated #{template.name} for #{key} #{object_name} to #{output_filename}"
        end
      rescue => e
        raise GeneratorError.new("Error generating #{template.name} for #{key} #{object_name}",e)
      end
    end
  end
end
