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

    def initialize(repository_key, key, generator_keys, target_dir)
      @repository_key, @key, @generator_keys, @target_dir = repository_key, key, generator_keys, target_dir
      @clobber_dir = false
      @namespace_key = :domgen
      @filter = nil
      yield self if block_given?
      define
    end

    private

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
            Domgen.generate(self.repository_key, self.target_dir, self.generator_keys, self.filter)
          rescue Exception => e
            print "An error occurred invoking the generator\n"
            puts $!
            puts $@
            raise e
          ensure
            Domgen::Logger.level = old_level
          end
        end
        @task_name = t.name
        Domgen::GenerateTask.append_to_all_task(self.namespace_key, t.name)
      end
    end

    private

    @@namespace_tasks = {}

    def self.append_to_all_task(namespace, task_name)
      all_task = @@namespace_tasks[namespace.to_s]
      unless all_task
        desc "Generate all #{namespace} artifacts"
        all_task = task("all")
        @@namespace_tasks[namespace.to_s] = all_task
      end
      all_task.enhance([task_name])
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
      end
    end
  end
end