module Domgen
  class << self
    def generate(repository_name, directory, generator_keys, filter)
      Domgen::Generator.generate(Domgen.repository_by_name(repository_name), directory, generator_keys, filter)
    end
  end

  module Generator
    def self.generate(repository, directory, generator_keys, filter)
      Logger.info "Generator started: Generating #{generator_keys.inspect}"

      templates = load_templates(generator_keys)

      templates.each do |template|
        template_name = File.basename(template.template_filename, '.erb')
        if :repository == template.scope
          if repository.generate?(template.generator_key) && (filter.nil? || filter.call(:repository, repository))
            Logger.debug "Generating #{template_name} for respository"
            render(directory, template, :repository, repository) do
              Logger.debug "Generated #{template_name} for respository"
            end
          end
        else
          repository.data_modules.each do |data_module|
            if :data_module == template.scope
              if data_module.generate?(template.generator_key) && (filter.nil? || filter.call(:data_module, data_module))
                Logger.debug "Generating #{template_name} for data_module #{data_module.name}"
                render(directory, template, :data_module, data_module) do
                  Logger.debug "Generated #{template_name} for data_module #{data_module.name}"
                end
              end
            else
              if :object_type == template.scope
                data_module.object_types.each do |object_type|
                  if object_type.generate?(template.generator_key) && (filter.nil? || filter.call(:object_type, object_type))
                    Logger.debug "Generating #{template_name} for object_type #{object_type.qualified_name}"
                    render(directory, template, :object_type, object_type) do
                      Logger.debug "Generated #{template_name} for object_type #{object_type.qualified_name}"
                    end
                  end
                end
              end

              if :service == template.scope
                data_module.services.each do |service|
                  if service.generate?(template.generator_key) && (filter.nil? || filter.call(:service, service))
                    Logger.debug "Generating #{template_name} for service #{service.qualified_name}"
                    render(directory, template, :service, service) do
                      Logger.debug "Generated #{template_name} for service #{service.qualified_name}"
                    end
                  end
                end
              end

              if :method == template.scope
                data_module.services.each do |service|
                  service.methods.each do |method|
                    Logger.debug "Generating #{template_name} for method #{method.qualified_name}"
                    if method.generate?(template.generator_key) && (filter.nil? || filter.call(:method, method))
                      render(directory, template, :method, method) do
                        Logger.debug "Generated #{template_name} for method #{method.qualified_name}"
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
      Logger.info "Generator completed"
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

    def self.load_templates(generator_keys)
      templates = []

      generator_keys.each do |generator_key|
        method_name = "define_#{generator_key}_templates".to_sym
        if self.respond_to? method_name
          new_templates = self.send(method_name)
          new_templates.each do |template|
            template.generator_key = generator_key
          end
          templates = templates + new_templates
        else
          Domgen.error("Missing define_#{generator_key}_templates method")
        end
      end

      templates
    end

    def self.render(target_basedir, template, key, value, &block)
      render_context = create_context(template, key, value)
      context_binding = render_context.context.send :binding
      return nil if !template.guard.nil? && !eval(template.guard, context_binding)
      output_filename = eval("\"#{template.output_filename_pattern}\"", context_binding)
      output_filename = File.join(target_basedir, output_filename)
      result = template.render_to_string(context_binding)
      FileUtils.mkdir_p File.dirname(output_filename)
      File.open(output_filename, 'w') { |f| f.write(result) }
      yield if output_filename
    end
  end
end
