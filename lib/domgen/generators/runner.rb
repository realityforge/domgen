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

module Domgen #nodoc
  module Generators #nodoc
    # A base class for writing command line tasks that load one or more
    # descriptors and run zer or more generators/template_sets
    class BaseRunner
      EXIT_CODE_SUCCESS = 0
      EXIT_CODE_UNABLE_TO_PARSE_ARGS = 50
      EXIT_CODE_UNEXPECTED_ARGS = 51
      EXIT_CODE_DESCRIPTOR_NO_EXIST = 52
      EXIT_CODE_NO_ELEMENT_NAME_SPECIFIED = 53
      EXIT_CODE_ELEMENT_NAME_NO_EXIST = 54

      def initialize
        @descriptors = []
        @generators = self.default_generators
        @target_dir = nil
        @element_name = nil
        @element_type_name_char_code = nil
        @verbose = false
        @debug = false
        @tool_name = File.basename($PROGRAM_NAME)
      end

      def default_generators
        []
      end

      def default_descriptor
        raise 'default_descriptor not implemented'
      end

      def element_type_name
        raise 'repository not implemented'
      end

      def log_container
        raise 'log_container not implemented'
      end

      def instance_container
        raise 'instance_container not implemented'
      end

      def template_set_container
        raise 'template_set_container not implemented'
      end

      def additional_loggers
        []
      end

      def element_type_name_char_code
        @element_type_name_char_code || self.element_type_name[0, 1]
      end

      def default_target_dir
        'generated'
      end

      attr_writer :verbose

      def verbose?
        !!@verbose
      end

      attr_writer :debug

      def debug?
        !!@debug
      end

      attr_writer :target_dir

      def target_dir
        @target_dir || self.default_target_dir
      end

      attr_accessor :generators

      attr_accessor :descriptors

      attr_accessor :element_name

      attr_accessor :tool_name

      def run
        require 'optparse'

        opt_parser = OptionParser.new do |opt|
          opt.banner = "Usage: #{tool_name} [OPTIONS]"
          opt.separator ''
          opt.separator 'Options'

          opt.on('-d', '--descriptor FILENAME', "the filename of a descriptor to be loaded. Multiple descriptors may be loaded. Defaults to 'resources.rb' if none specified.") do |arg|
            self.descriptors << arg
          end

          opt.on("-#{self.element_type_name_char_code}",
                 "--#{self.element_type_name} NAME",
                 "the name of the #{self.element_type_name} to load. Defaults to the the name of the only #{element_type_name} if there is only one #{self.element_type_name} defined by the descriptors, otherwise must be specified.") do |arg|
            self.element_name = arg
          end

          opt.on('-g', '--generators GENERATORS', "the comma separated list of generators to run. Defaults to #{default_generators.inspect}") do |arg|
            self.generators += arg.split(',').collect { |g| g.to_sym }
          end

          opt.on('-t', '--target-dir DIR', "the directory into which to generate artifacts. Defaults to '#{self.default_target_dir}'.") do |arg|
            self.target_dir = arg
          end

          opt.on('-v', '--verbose', 'turn on verbose logging.') do
            self.verbose = true
          end

          opt.on('--debug', 'turn on debug logging.') do
            self.verbose = true
            self.debug = true
          end

          opt.on('-h', '--help', 'help') do
            puts opt_parser
            exit(EXIT_CODE_SUCCESS)
          end
        end

        args = ARGV.dup
        begin
          opt_parser.parse!(args)
        rescue => e
          puts "Error: #{e.message}"
          exit(EXIT_CODE_UNABLE_TO_PARSE_ARGS)
        end

        if args.length != 0
          puts "Unexpected arguments #{args.inspect} passed to command"
          puts opt_parser
          exit(EXIT_CODE_UNEXPECTED_ARGS)
        end

        loggers = [self.log_container.const_get(:Logger), Domgen::Logger] + self.additional_loggers

        log_level = debug? ? ::Logger::DEBUG : verbose? ? ::Logger::INFO : ::Logger::WARN
        Domgen::Logging.set_levels(log_level, *loggers)

        if 0 == self.descriptors.size
          puts "No descriptor specified. Defaulting to #{default_descriptor}"
          self.descriptors << default_descriptor
        end

        if verbose?
          puts "#{Domgen::Naming.humanize(self.element_type_name)} Name: #{self.element_name || 'Unspecified'}"
          puts "Target Dir: #{self.target_dir}"
          if self.descriptors.size == 1
            puts "Descriptor: #{self.descriptors[0]}"
          else
            puts 'Descriptors:'
            self.descriptors.each do |descriptor|
              puts "  * #{descriptor}"
            end
          end
          puts 'Generators:'
          self.generators.each do |generator|
            puts "  * #{generator}"
          end
        end

        self.descriptors.each do |descriptor|
          puts "Loading descriptor: #{descriptor}" if verbose?
          filename = File.expand_path(descriptor)
          unless File.exist?(filename)
            puts "Descriptor file #{filename} does not exist"
            exit(EXIT_CODE_DESCRIPTOR_NO_EXIST)
          end
          load_descriptor(filename)
          puts "Descriptor loaded: #{descriptor}" if verbose?
        end

        unless self.element_name
          element_names = self.instance_container.send(Domgen::Naming.pluralize(self.element_type_name).to_sym).collect { |r| r.name }
          if element_names.size == 1
            self.element_name = element_names[0]
            puts "Derived default #{Domgen::Naming.humanize(self.element_type_name)} name: #{self.element_name}" if verbose?
          else
            puts "No #{Domgen::Naming.humanize(self.element_type_name).downcase} name specified and #{Domgen::Naming.humanize(element_type_name).downcase} name could not be determined. Please specify one of the valid #{Domgen::Naming.humanize(self.element_type_name).downcase} names: #{element_names.join(', ')}"
            exit(EXIT_CODE_NO_ELEMENT_NAME_SPECIFIED)
          end
        end

        unless self.instance_container.send(:"#{self.element_type_name}_by_name?", self.element_name)
          puts "Specified #{Domgen::Naming.humanize(self.element_type_name).downcase} name '#{self.element_name}' does not exist in descriptors."
          exit(EXIT_CODE_ELEMENT_NAME_NO_EXIST)
        end

        element = self.instance_container.send(:"#{self.element_type_name}_by_name", self.element_name)

        self.template_set_container.generator.generate(element_type_name.to_sym,
                                                       element,
                                                       File.expand_path(self.target_dir),
                                                       self.generators,
                                                       nil)

        exit EXIT_CODE_SUCCESS
      end

      def load_descriptor(filename)
        pre_load(filename)
        require filename
        post_load(filename)
      end

      def pre_load(filename)
      end

      def post_load(filename)
      end
    end
  end
end
