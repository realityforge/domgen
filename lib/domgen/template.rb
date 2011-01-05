module Domgen
  module Generator
    class Template
      attr_reader :template_filename
      attr_reader :output_filename_pattern
      attr_reader :guard
      attr_reader :helpers
      attr_reader :scope
      attr_accessor :generator_key

      def initialize(scope, template_filename, output_filename_pattern, helpers = [], guard = nil)
        @scope = scope
        @template_filename = template_filename
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
          @template = ERB.new(IO.read(template_filename))
        end
        @template
      end
    end

    class InlineTemplate < Template
      def initialize(scope, render_method, output_filename_pattern, helpers = [], guard = nil)
        super(scope, "inline", output_filename_pattern, helpers, guard)
        @render_method = render_method
      end

      def render_to_string(context_binding)
        eval(@render_method, context_binding)
      end
    end
  end
end
