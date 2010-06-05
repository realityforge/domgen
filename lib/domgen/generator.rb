require 'erb'
require 'fileutils'

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

    class Template
      class << self
        attr_accessor :template_dir
      end

      self.template_dir = "#{File.dirname(__FILE__)}/templates"

      attr_reader :template_name
      attr_reader :output_filename_pattern
      attr_reader :guard
      attr_reader :helpers
      attr_reader :scope
      attr_accessor :extension_key

      def initialize(scope, template_name, output_filename_pattern, helpers = [], guard = nil)
        @scope = scope
        @template_name = template_name
        @output_filename_pattern = output_filename_pattern
        @helpers = helpers
        @guard = guard
      end

      def render_to_string(context_binding)
        erb_instance.result(context_binding)
      end

      protected

      def erb_instance
        unless @template
          filename = "#{self.class.template_dir}/#{template_name}.erb"
          @template = ERB.new(IO.read(filename))
        end
        @template
      end

    end

    class RenderContext
      def initialize
        @helpers = []
        @variables = {}
      end

      def add_helper(module_type)
        @helpers << module_type
      end

      def set_local_variable(key, value)
        @variables[key] = value
      end

      def context
        context = Object.new
        @helpers.each do |helper|
          context.include helper
        end
        @variables.each_pair do |k, v|
          context.instance_eval "def #{k}; @#{k}; end"
          context.instance_variable_set "@#{k}".to_sym, v
        end

        context
      end
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
