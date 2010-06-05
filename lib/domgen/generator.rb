module Domgen
  module Generator
    DEFAULT_ARTIFACTS = [:jpa, :active_record, :sql]

    def self.generate(schema_set, directory, artifacts = nil)
      artifacts = DEFAULT_ARTIFACTS unless artifacts
      Logger.info "Generator started: artifacts = #{artifacts.inspect}"

      templates = load_templates

      templates.each do |template|
        if :schema_set == template.scope
          context = RenderContext.new
          context.set_local_variable(:schema_set, schema_set)
          render(directory, template, context) do
            Logger.debug "Generated #{template.template_name} for schema set"
          end          
        else
          schema_set.schemas.each do |schema|
            if :schema == template.scope
              context = RenderContext.new
              context.set_local_variable(:schema, schema)
              render(directory, template, context) do 
                Logger.debug "Generated #{template.template_name} for schema #{schema.name}"
              end
            else
              schema.object_types.each do |object_type|
                context = RenderContext.new
                context.set_local_variable(:object_type, object_type)
                render(directory, template, context) do
                  Logger.debug "Generated #{template.template_name} for object_type #{schema.name}.#{object_type.name}"
                end                
              end
            end
          end
        end
      end
      Logger.info "Generator completed"
    end
    
    private

    def self.load_templates
      templates = []

      artifacts.each do |artifact|
        method_name = "define_#{artifact}_templates".to_sym
        if self.respond_to? method_name
          new_templates = self.send(method_name)
          new_templates.each do |template|
            template.extension_key = artifact
          end
          templates = templates + new_templates
        else
          raise "Missing define_#{artifact}_templates method"
        end
      end

      templates
    end

    def self.render(target_basedir, template, render_context, &block)
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
