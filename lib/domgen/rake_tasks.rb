module Domgen
  class GenerateTask
    attr_accessor :clobber_dir
    attr_accessor :description
    attr_accessor :namespace_key
    attr_accessor :filter

    attr_reader :repository_key
    attr_reader :key
    attr_reader :generator_keys
    attr_reader :target_dir

    attr_reader :task_name

    def initialize(repository_key, key, generator_keys, target_dir)
      @repository_key, @key, @generator_keys, @target_dir = repository_key, key, generator_keys, target_dir
      @clobber_dir = true
      @namespace_key = :domgen
      @filter = nil
      yield self if block_given?
      define
    end

    private

    def define
      desc self.description || "Generates the #{key} artifacts."
      namespace self.namespace_key do
        t = task self.key => ["#{self.namespace_key}:load"] do
          begin
            FileUtils.rm_rf(self.target_dir) if self.clobber_dir
            Domgen.generate(self.repository_key, self.target_dir, self.generator_keys, self.filter)
          rescue Exception => e
            print "An error occurred invoking the generator\n"
            puts $!
            puts $@
            raise e
          end
        end
        @task_name = t.name
      end
    end
  end

  class LoadSchema
    attr_accessor :description
    attr_accessor :namespace_key

    attr_reader :filename

    def initialize(filename)
      @filename = filename
      @namespace_key = :domgen
      yield self if block_given?
      define
    end

    private

    def define
      desc self.description
      namespace self.namespace_key do
        task :load => [self.filename] do
          begin
            #Domgen::Logger.level = Logger::INFO
            require self.filename
          rescue Exception => e
            print "An error occurred loading respository\n"
            puts $!
            puts $@
            raise e
          end
        end
      end
    end
  end
end