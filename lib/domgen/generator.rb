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
              if :object_type == template.scope
                data_module.object_types.each do |object_type|
                  if template.applicable?(object_type) && (filter.nil? || filter.call(:object_type, object_type))
                    render(directory, template, :object_type, object_type)
                  end
                end
              end

              if :enumeration == template.scope
                data_module.enumerations.each do |object_type|
                  if template.applicable?(object_type) && (filter.nil? || filter.call(:enumeration, object_type))
                    render(directory, template, :enumeration, object_type)
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
      object_name = value.respond_to?(:qualified_name) ? value.qualified_name : value.name
      Logger.debug "Generating #{template.template_name} for #{key} #{object_name}"

      render_context = create_context(template, key, value)
      context_binding = render_context.context.send :binding
      return nil if !template.guard.nil? && !eval(template.guard, context_binding)
      output_filename = eval("\"#{template.output_filename_pattern}\"", context_binding)
      output_filename = File.join(target_basedir, output_filename)
      result = template.render_to_string(context_binding)
      FileUtils.mkdir_p File.dirname(output_filename)
      File.open(output_filename, 'w') { |f| f.write(result) }
      Logger.debug "Generated #{template.template_name} for #{key} #{object_name} to #{output_filename}"
    end
  end
end
