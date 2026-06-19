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
    module Rake #nodoc

      # This class is typically mixed into Myproject::Build constants to add simplified mechanisms for defining build tasks
      module BuildTasksMixin
        def define_load_task(filename = nil, &block)
          base_directory = File.dirname(::Buildr.application.buildfile.to_s)
          candidate_file = File.expand_path("#{base_directory}/#{default_descriptor_filename}")
          if filename.nil?
            filename = candidate_file
          elsif File.expand_path(filename) == candidate_file
            self.log_container.warn("#{self.name}.define_load_task() passed parameter '#{filename}' which is the same value as the default parameter. This parameter can be removed.")
          end
          self.const_get(:LoadDescriptor).new(File.expand_path(filename), &block)
        end

        def define_generate_task(generator_keys, options = {}, &block)
          element_key = options[:"#{root_element_type}_key"]
          target_dir = options[:target_dir]
          buildr_project = options[:buildr_project]
          clean_generated_files = options[:clean_generated_files].nil? ? true : !!options[:clean_generated_files]
          keep_file_patterns = options[:keep_file_patterns] || []
          keep_file_names = options[:keep_file_names] || []

          if buildr_project.nil? && ::Buildr.application.current_scope.size > 0
            buildr_project = ::Buildr.project(::Buildr.application.current_scope.join(':')) rescue nil
          end

          build_key = options[:key] || (buildr_project.nil? ? :default : buildr_project.name.split(':').last)

          if target_dir
            base_directory = File.dirname(::Buildr.application.buildfile.to_s)
            target_dir = File.expand_path(target_dir, base_directory)
          end

          if target_dir.nil? && !buildr_project.nil?
            if clean_generated_files
              target_dir = buildr_project._(:target, :generated, self.generated_type_path_prefix, build_key)
            elsif buildr_project.inline_generated_source?
              target_dir = buildr_project._('src')
            else
              target_dir = buildr_project._(:srcgen, self.generated_type_path_prefix, build_key)
            end
          elsif !target_dir.nil? && !buildr_project.nil?
            self.log_container.warn("#{self.name}.define_generate_task specifies a target directory parameter but it can be be derived from the context. The parameter should be removed.")
          end

          if target_dir.nil?
            self.log_container.error("#{self.name}.define_generate_task should specify a target directory as it can not be derived from the context.")
          end

          if clean_generated_files && buildr_project
            buildr_project.clean { rm_rf target_dir }
          end

          self.const_get(:GenerateTask).new(element_key, build_key, generator_keys, target_dir, buildr_project, clean_generated_files) do |g|
            g.keep_filter = Proc.new do |file|
              filename = file.to_s
              result = keep_file_names.include?(filename)
              keep_file_patterns.each do |keep_file_pattern|
                result = true if keep_file_pattern =~ filename
              end
              result
            end if !keep_file_patterns.empty? || !keep_file_names.empty?
            block.call(g)
          end

          target_dir
        end
      end

      # This is the base class used to define tasks that generate artifacts using templates
      class BaseGenerateTask
        attr_accessor :description
        attr_accessor :namespace_key
        attr_accessor :filter
        attr_accessor :keep_filter
        attr_writer :verbose
        attr_writer :mark_as_generated_in_ide

        attr_reader :root_element_key
        attr_reader :key
        attr_reader :generator_keys
        attr_reader :target_dir

        attr_reader :task_name

        def initialize(root_element_key, key, generator_keys, target_dir, buildr_project = nil, clean_generated_files = true)
          @root_element_key = root_element_key
          @key = key
          @generator_keys = generator_keys
          @namespace_key = self.default_namespace_key
          @filter = nil
          @keep_filter = nil
          # Turn on verbose messages if buildr is turned on tracing
          @verbose = trace?
          @mark_as_generated_in_ide = true
          @clean_generated_files = clean_generated_files
          @target_dir = target_dir
          yield self if block_given?
          define
          @templates = self.template_set_container.generator.load_templates_from_template_sets(generator_keys)
          Domgen::Generators::Buildr.configure_buildr_project(buildr_project, task_name, @templates, target_dir, mark_as_generated_in_ide?, clean_generated_files?)
        end

        protected

        def default_namespace_key
          Domgen.error('default_namespace_key should be implemented')
        end

        def template_set_container
          Domgen.error('template_set_container should be implemented')
        end

        def root_element_type
          Domgen.error('root_element_type should be implemented')
        end

        def log_container
          Domgen.error('log_container should be implemented')
        end

        def instance_container
          Domgen.error('instance_container should be implemented')
        end

        def root_elements_key
          Domgen::Naming.pluralize(root_element_type)
        end

        def validate_root_element(element)
        end

        def root_element
          element = nil
          if self.root_element_key
            element = self.instance_container.send(:"#{self.root_element_key}_by_name", self.root_element_key)
            if self.instance_container.send(self.root_elements_key).size == 1
              self.log_container.warn("Task #{full_task_name} specifies a #{self.root_element_type}_key parameter but it can be be derived as there is only a single repository. The parameter should be removed.")
            end
          elsif self.root_element_key.nil?
            elements = self.instance_container.send(self.root_elements_key)
            if 1 == elements.size
              element = elements[0]
            else
              self.log_container.error("Task #{full_task_name} does not specify a #{self.root_element_type}_key parameter and it can not be derived. Candidate #{self.root_elements_key} include #{elements.collect { |r| r.name }.inspect}")
            end
          end

          validate_root_element(element)

          element
        end

        private

        def mark_as_generated_in_ide?
          !!@mark_as_generated_in_ide
        end

        def clean_generated_files?
          !!@clean_generated_files
        end

        def verbose?
          !!@verbose
        end

        def full_task_name
          "#{self.namespace_key}:#{self.key}"
        end

        def define
          desc self.description || "Generates the #{key} artifacts."
          namespace self.namespace_key do
            t = task self.key => ["#{self.namespace_key}:load"] do
              begin

                Domgen::Logging.set_levels(verbose? ? ::Logger::DEBUG : ::Logger::WARN,
                                            self.log_container.const_get(:Logger)) do
                  self.log_container.info "Generator started: Generating #{self.generator_keys.inspect}"
                  self.template_set_container.generator.
                    generate(self.root_element_type, self.root_element, self.target_dir, @templates, self.filter, self.keep_filter)
                end
              rescue Domgen::Generators::GeneratorError => e
                puts e.message
                if e.cause
                  puts e.cause.class.name.to_s
                  puts e.cause.backtrace.join("\n")
                end
                raise e.message
              end
            end
            @task_name = t.name
            Domgen::Generators::Rake::TaskRegistry.get_aggregate_task(self.namespace_key).enhance([t.name])
          end
        end
      end

      # Base class that defines tasks to load the resource descriptors into application
      # This will load the file such as 'architecture.rb', 'noft.rb' or 'resgen.rb'
      class BaseLoadDescriptor
        attr_accessor :description
        attr_accessor :namespace_key
        attr_writer :verbose

        attr_reader :filename

        def initialize(filename)
          @filename = filename
          @namespace_key = self.default_namespace_key
          yield self if block_given?
          define
        end

        protected

        def default_namespace_key
          Domgen.error('default_namespace_key should be implemented')
        end

        def log_container
          Domgen.error('log_container should be implemented')
        end

        def pre_load
        end

        def post_load
        end

        private

        def verbose?
          !!@verbose
        end

        def define
          namespace self.namespace_key do
            task :preload

            task :postload

            desc self.description
            task :load => [:preload, self.filename] do
              begin
                self.pre_load
                Domgen::Logging.set_levels(verbose? ? ::Logger::DEBUG : ::Logger::WARN,
                                            self.log_container.const_get(:Logger)) do

                  require self.filename
                end
              rescue Exception => e
                print "An error occurred loading repository\n"
                puts $!
                puts $@
                raise e
              ensure
                self.post_load
              end
              task("#{self.namespace_key}:postload").invoke
            end
            Domgen::Generators::Rake::TaskRegistry.get_aggregate_task(self.namespace_key)
          end
        end
      end

      class TaskRegistry
        class << self
          def get_aggregate_task(namespace)
            all_task = namespace_tasks[namespace.to_s]
            unless all_task
              desc "Generate all #{namespace} artifacts"
              all_task = task('all')
              namespace_tasks[namespace.to_s] = all_task
            end
            all_task
          end

          private

          def namespace_tasks
            @namespace_tasks ||= {}
          end
        end
      end
    end
  end
end
