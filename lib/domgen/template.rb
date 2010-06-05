module Domgen
  module Generator
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
      attr_accessor :generator_key

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
  end
end
