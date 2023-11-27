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
  class Build #nodoc
    def self.define_load_task(filename = nil, &block)
      base_directory = File.dirname(Buildr.application.buildfile.to_s)
      candidate_file = File.expand_path("#{base_directory}/architecture.rb")
      if filename.nil?
        filename = candidate_file
      elsif File.expand_path(filename) == candidate_file
        Domgen.warn("Domgen::Build.define_load_task() passed parameter '#{filename}' which is the same value as the default parameter. This parameter can be removed.")
      end
      Domgen::LoadSchema.new(File.expand_path(filename), &block)
    end

    def self.define_generate_task(generator_keys, options = {}, &block)
      repository_key = options[:repository_key]
      target_dir = options[:target_dir]
      buildr_project = options[:buildr_project]
      clean_generated_files = options[:clean_generated_files].nil? ? true : !!options[:clean_generated_files]
      keep_file_patterns = options[:keep_file_patterns] || []
      keep_file_names = options[:keep_file_names] || []
      if buildr_project.nil? && Buildr.application.current_scope.size > 0
        buildr_project = Buildr.project(Buildr.application.current_scope.join(':')) rescue nil
      end

      build_key = options[:key] || (buildr_project.nil? ? :default : buildr_project.name.split(':').last)

      if target_dir
        base_directory = File.dirname(Buildr.application.buildfile.to_s)
        target_dir = File.expand_path(target_dir, base_directory)
      end

      if target_dir.nil? && !buildr_project.nil?
        if clean_generated_files
          target_dir = buildr_project._(:target, :generated, 'domgen', build_key)
        elsif buildr_project.inline_generated_source?
          target_dir = buildr_project._('src')
        else
          target_dir = buildr_project._(:srcgen, 'domgen', build_key)
        end
      elsif !target_dir.nil? && !buildr_project.nil?
        Domgen.warn('Domgen::Build.define_generate_task specifies a target directory parameter but it can be be derived from the context. The parameter should be removed.')
      end

      if target_dir.nil?
        Domgen.error('Domgen::Build.define_generate_task should specify a target directory as it can not be derived from the context.')
      end

      if clean_generated_files && buildr_project
        buildr_project.clean { rm_rf target_dir }
      end

      Domgen::GenerateTask.new(repository_key, build_key, generator_keys, target_dir, buildr_project, clean_generated_files) do |g|
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

  class GenerateTask
    attr_accessor :description
    attr_accessor :namespace_key
    attr_accessor :filter
    attr_accessor :keep_filter
    attr_writer :verbose
    attr_writer :mark_as_generated_in_ide

    attr_reader :repository_key
    attr_reader :key
    attr_reader :generator_keys
    attr_reader :target_dir

    attr_reader :task_name

    def initialize(repository_key, key, generator_keys, target_dir, buildr_project = nil, clean_generated_files = true)
      @repository_key, @key, @generator_keys, @buildr_project =
        repository_key, key, generator_keys, buildr_project
      @namespace_key = :domgen
      @filter = nil
      @keep_filter = nil
      @template_map = {}
      # Turn on verbose messages if buildr is turned on tracing
      @verbose = trace?
      if buildr_project.nil? && Buildr.application.current_scope.size > 0
        buildr_project = Buildr.project(Buildr.application.current_scope.join(':')) rescue nil
      end
      @target_dir = target_dir
      @mark_as_generated_in_ide = true
      @clean_generated_files = clean_generated_files
      yield self if block_given?
      define
      @templates = Domgen.generator.load_templates_from_template_sets(generator_keys)
      Reality::Generators::Buildr.configure_buildr_project(buildr_project, task_name, @templates, target_dir, mark_as_generated_in_ide?, clean_generated_files?)
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
            repository = nil
            if self.repository_key
              repository = Domgen.repository_by_name(self.repository_key)
              if Domgen.repositories.size == 1
                Domgen.warn("Domgen task #{full_task_name} specifies a repository_key parameter but it can be be derived as there is only a single repository. The parameter should be removed.")
              end
            elsif self.repository_key.nil?
              repositories = Domgen.repositories
              if repositories.size == 1
                repository = repositories[0]
              else
                Domgen.error("Domgen task #{full_task_name} does not specify a repository_key parameter and it can not be derived. Candidate repositories include #{repositories.collect { |r| r.name }.inspect}")
              end
            end

            Reality::Logging.set_levels(verbose? ? ::Logger::DEBUG : ::Logger::WARN,
                                        Domgen::Logger,
                                        Reality::Generators::Logger,
                                        Reality::Facets::Logger) do
              Domgen.info "Generator started: Generating #{self.generator_keys.inspect}"
              Domgen.generator.generate(:repository, repository, self.target_dir, @templates, self.filter, self.keep_filter)
            end
          rescue Reality::Generators::GeneratorError => e
            puts e.message
            if e.cause
              puts e.cause.class.name.to_s
              puts e.cause.backtrace.join("\n")
            end
            raise e.message
          end
        end
        @task_name = t.name
        Domgen::TaskRegistry.append_to_all_task(self.namespace_key, t.name)
      end
    end
  end

  class LoadSchema
    attr_accessor :description
    attr_accessor :namespace_key
    attr_writer :verbose

    attr_reader :filename

    def initialize(filename)
      @filename = filename
      @namespace_key = :domgen
      yield self if block_given?
      define
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
            Domgen.current_filename = self.filename
            Reality::Logging.set_levels(verbose? ? ::Logger::DEBUG : ::Logger::WARN,
                                        Domgen::Logger,
                                        Reality::Generators::Logger,
                                        Reality::Facets::Logger) do
              require self.filename
            end
          rescue Exception => e
            print "An error occurred loading repository\n"
            puts $!
            puts $@
            raise e
          ensure
            Domgen.current_filename = nil
          end
          task("#{self.namespace_key}:postload").invoke
        end
        Domgen::TaskRegistry.get_aggregate_task(self.namespace_key)
      end
    end
  end

  class TaskRegistry
    @@namespace_tasks = {}

    def self.append_to_all_task(namespace, task_name)
      get_aggregate_task(namespace).enhance([task_name])
    end

    def self.get_aggregate_task(namespace)
      all_task = @@namespace_tasks[namespace.to_s]
      unless all_task
        desc "Generate all #{namespace} artifacts"
        all_task = task('all')
        @@namespace_tasks[namespace.to_s] = all_task
      end
      all_task
    end

  end
end
