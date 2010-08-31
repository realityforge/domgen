module Domgen
  class << self
    def generate(schema_set_name, directory, generator_keys, filter)
      Domgen::Generator.generate(Domgen.schema_set_by_name(schema_set_name), directory, generator_keys, filter)
    end
  end

  module Generator
    def self.generate(schema_set, directory, generator_keys, filter)
      Logger.info "Generator started: Generating #{generator_keys.inspect}"

      templates = load_templates(generator_keys)

      templates.each do |template|
        template_name = File.basename(template.template_filename,'.erb')
        if :schema_set == template.scope
          if schema_set.generate?(template.generator_key) && (filter.nil? || filter.call(:schema_set, schema_set))
            render(directory, template, :schema_set, schema_set) do
              Logger.debug "Generated #{template_name} for schema set"
            end
          end
        else
          schema_set.schemas.each do |schema|
            if :schema == template.scope
              if schema.generate?(template.generator_key) && (filter.nil? || filter.call(:schema, schema))
                render(directory, template, :schema, schema) do
                  Logger.debug "Generated #{template_name} for schema #{schema.name}"
                end
              end
            else
              schema.object_types.each do |object_type|
                if object_type.generate?(template.generator_key) && (filter.nil? || filter.call(:object_type, object_type))
                  render(directory, template, :object_type, object_type) do
                    Logger.debug "Generated #{template_name} for object_type #{schema.name}.#{object_type.name}"
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
