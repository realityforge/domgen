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

      template_set.per_schema_set.each do |template_map|
        Logger.debug "Generator: #{template_map.template_name} => #{template_map.basedir} for schema set"
        template_map.generate(directory, schema_set)
      end

      template_set.per_schema.each do |template_map|
        schema_set.schemas.each do |schema|
          Logger.debug "Generator: #{template_map.template_name} => #{template_map.basedir} for schema #{schema.name}"
          template_map.generate(directory, schema)
        end
      end

      template_set.per_object_type.each do |template_map|
        schema_set.schemas.each do |schema|
          schema.object_types.each do |object_type|
            Logger.debug "Generator: #{template_map.template_name} => #{template_map.basedir} for object_type #{object_type.name} in schema #{schema.name}"
            template_map.generate(directory, object_type)
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
      attr_reader :template_name
      attr_reader :output_filename_pattern
      attr_reader :basedir

      def initialize(template_name, output_filename_pattern, basedir)
        @template_name, @output_filename_pattern, @basedir = template_name, output_filename_pattern, basedir
      end

      def generate(basedir, context)
        context_binding = context.send :binding
        output_filename = eval("\"#{output_filename_pattern}\"", context_binding)
        output_dir = eval("\"#{self.basedir}\"", context_binding)
        output_filename = File.join(basedir, output_dir, output_filename)
        result = erb_instance.result(context_binding)
        FileUtils.mkdir_p File.dirname(output_filename)
        File.open(output_filename, 'w') { |f| f.write(result) }
      end

      protected

      def erb_instance
        unless @template
          filename = "#{File.dirname(__FILE__)}/templates/#{template_name}.erb"
          @template = ERB.new(IO.read(filename))
        end
        @template
      end
    end
  end
end
