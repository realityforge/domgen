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

module Domgen
  class GenerateTask
    attr_accessor :clobber_dir
    attr_accessor :description
    attr_accessor :namespace_key
    attr_accessor :filter
    attr_writer :verbose

    attr_reader :repository_key
    attr_reader :key
    attr_reader :generator_keys
    attr_reader :target_dir

    attr_reader :task_name

    def initialize(repository_key, key, generator_keys, target_dir, buildr_project = nil)
      @repository_key, @key, @generator_keys, @target_dir, @buildr_project =
        repository_key, key, generator_keys, target_dir, buildr_project
      @clobber_dir = false
      @namespace_key = :domgen
      @filter = nil
      @template_map = {}
      yield self if block_given?
      define
      load_templates(generator_keys)
      if buildr_project.nil? && Buildr.application.current_scope.size > 0
        buildr_project = Buildr.project(Buildr.application.current_scope.join(':')) rescue nil
      end
      if buildr_project
        file(File.expand_path(target_dir) => [task_name])

        # Is there java source generated in project?
        if templates.any?{|template| template.output_filename_pattern =~ /^main\/java\/.*/}
          main_java_dir = "#{target_dir}/main/java"
          file(main_java_dir => [task_name]) do
            mkdir_p main_java_dir
          end
          buildr_project.compile.from main_java_dir
          # Need to force this as it may have already been cached and thus will not recalculate
          buildr_project.iml.main_source_directories << main_java_dir if buildr_project.iml?
        end

        # Is there resources generated in project?
        if templates.any?{|template| template.output_filename_pattern =~ /^main\/resources\/.*/}
          main_resources_dir = "#{target_dir}/main/resources"
          file(main_resources_dir => [task_name]) do
            mkdir_p main_resources_dir
          end
          buildr_project.resources.enhance([task_name])
          buildr_project.resources.filter.into buildr_project.path_to(:target, :main, :resources) unless buildr_project.resources.target
          buildr_project.resources do |t|
            t.enhance do
              if File.exist?(main_resources_dir)
                FileUtils.mkdir_p buildr_project.resources.target.to_s
                FileUtils.cp_r "#{main_resources_dir}/.", buildr_project.resources.target.to_s
              end
            end
          end
          buildr_project.iml.main_source_directories << main_resources_dir if buildr_project.iml?
        end

        # Is there assets generated in project?
        if templates.any?{|template| template.output_filename_pattern =~ /^main\/webapp\/.*/}
          webapp_dir = File.expand_path("#{target_dir}/main/webapp")
          buildr_project.assets.enhance([task_name])
          buildr_project.assets.paths << file(webapp_dir => [task_name]) do
            mkdir_p webapp_dir
          end
        end

        # Is there test java source generated in project?
        if templates.any?{|template| template.output_filename_pattern =~ /^test\/java\/.*/}
          test_java_dir = "#{target_dir}/test/java"
          file(test_java_dir => [task_name]) do
            mkdir_p test_java_dir
          end
          buildr_project.test.compile.from test_java_dir
          # Need to force this as it may have already been cached and thus will not recalculate
          buildr_project.iml.test_source_directories << test_java_dir if buildr_project.iml?
        end

        # Is there resources generated in project?
        if templates.any?{|template| template.output_filename_pattern =~ /^test\/resources\/.*/}
          test_resources_dir = "#{target_dir}/test/resources"
          file(test_resources_dir => [task_name]) do
            mkdir_p test_resources_dir
          end
          buildr_project.test.resources.enhance([task_name])
          buildr_project.test.resources.filter.into buildr_project.path_to(:target, :test, :resources) unless buildr_project.test.resources.target
          buildr_project.test.resources do |t|
            t.enhance do
              if File.exist?(test_resources_dir)
                FileUtils.mkdir_p buildr_project.test.resources.target.to_s
                FileUtils.cp_r "#{test_resources_dir}/.", buildr_project.test.resources.target.to_s
              end
            end
          end
          buildr_project.iml.test_source_directories << test_resources_dir if buildr_project.iml?
        end
      end
    end

    def templates
      @template_map.values
    end

    private

    def load_templates(names, processed_template_sets = [])
      names.select{|name| !processed_template_sets.include?(name)}.each do |name|
        template_set = Domgen.template_set_by_name(name)
        processed_template_sets << name
        load_templates(template_set.required_template_sets, processed_template_sets)
        template_set.templates.each do |template|
          @template_map[template.name] = template
        end
      end
    end

    def verbose?
      !!@verbose
    end

    def define
      desc self.description || "Generates the #{key} artifacts."
      namespace self.namespace_key do
        t = task self.key => ["#{self.namespace_key}:load"] do
          old_level = Domgen::Logger.level
          begin
            FileUtils.rm_rf(self.target_dir) if self.clobber_dir
            Domgen::Logger.level = verbose? ? ::Logger::DEBUG : ::Logger::WARN
            Logger.info "Generator started: Generating #{self.generator_keys.inspect}"
            Domgen::Generator.generate(Domgen.repository_by_name(self.repository_key),
                                        self.target_dir,
                                        self.templates,
                                        self.filter)
          rescue Domgen::Generator::GeneratorError => e
            puts e.message
            puts e.cause.class.name.to_s
            puts e.cause.backtrace.join("\n")
            raise e.message
          ensure
            Domgen::Logger.level = old_level
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
      desc self.description
      namespace self.namespace_key do
        task :load => [self.filename] do
          old_level = Domgen::Logger.level
          begin
            Domgen::Logger.level = verbose? ? ::Logger::DEBUG : ::Logger::WARN
            require self.filename
          rescue Exception => e
            print "An error occurred loading respository\n"
            puts $!
            puts $@
            raise e
          ensure
            Domgen::Logger.level = old_level
          end
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
        all_task = task("all")
        @@namespace_tasks[namespace.to_s] = all_task
      end
      all_task
    end

  end
end
