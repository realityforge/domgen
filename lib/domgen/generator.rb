require 'erb'
require 'fileutils'

module Domgen
  module Generator
    DEFAULT_ARTIFACTS = [:jpa, :active_record, :sql]

    def self.generate(schema_set, directory, artifacts = nil)
      artifacts = DEFAULT_ARTIFACTS unless artifacts
      Logger.info "Generator started: artifacts = #{artifacts.inspect}"

      template_set = TemplateSet.new

      artifacts.each do |artifact|
        method_name = "define_#{artifact}_templates".to_sym
        if self.respond_to? method_name
          self.send method_name, template_set
        else
          raise "Missing define_#{artifact}_templates method"
        end
      end

      template_set.per_schema_set.each do |template|
        context = RenderContext.new
        context.set_local_variable(:schema_set, schema_set)
        output_filename = render(directory, template, context)
        Logger.debug "Generated #{template.template_name} for schema set" if output_filename
      end

      template_set.per_schema.each do |template|
        context = RenderContext.new
        schema_set.schemas.each do |schema|
          context.set_local_variable(:schema, schema)
          output_filename = render(directory, template, context)
          Logger.debug "Generated #{template.template_name} for schema #{schema.name}" if output_filename
        end
      end

      template_set.per_object_type.each do |template|
        context = RenderContext.new
        schema_set.schemas.each do |schema|
          schema.object_types.each do |object_type|
            context.set_local_variable(:object_type, object_type)
            output_filename = render(directory, template, context)
            Logger.debug "Generated #{template.template_name} for object_type #{schema.name}.#{object_type.name}" if output_filename
          end
        end
      end
      Logger.info "Generator completed"
    end

    class TemplateSet
      attr_accessor :per_schema_set
      attr_accessor :per_schema
      attr_accessor :per_object_type

      def initialize
        self.per_schema_set = []
        self.per_schema = []
        self.per_object_type = []
      end
    end

    class Template
      class << self
        attr_accessor :template_dir
      end

      self.template_dir = "#{File.dirname(__FILE__)}/templates"


      attr_reader :template_name
      attr_reader :template_type
      attr_reader :output_filename_pattern
      attr_reader :basedir
      attr_reader :guard

      def initialize(template_name, output_filename_pattern, basedir, guard = nil, template_type = :erb)
        @template_name, @output_filename_pattern, @basedir, @guard, @template_type =
            template_name, output_filename_pattern, basedir, guard, template_type
      end

      def render_to_string(context_binding)
        return erb_instance.result(context_binding) if :erb == template_type
        raise "Unknown template_type #{template_type}"
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

    def self.render(target_basedir, template, render_context)
      context_binding = render_context.context.send :binding
      return nil if !template.guard.nil? && !eval(template.guard, context_binding)
      output_filename = eval("\"#{template.output_filename_pattern}\"", context_binding)
      output_dir = eval("\"#{template.basedir}\"", context_binding)
      output_filename = File.join(target_basedir, output_dir, output_filename)
      result = template.render_to_string(context_binding)
      FileUtils.mkdir_p File.dirname(output_filename)
      File.open(output_filename, 'w') { |f| f.write(result) }
      return output_filename
    end
  end
end
