module Domgen
  class GenerateTask
    attr_accessor :clobber_dir
    attr_accessor :description
    attr_accessor :namespace_key
    attr_accessor :filter

    attr_reader :schema_set_key
    attr_reader :key
    attr_reader :generator_keys
    attr_reader :target_dir

    def initialize(schema_set_key, key, generator_keys, target_dir)
      @schema_set_key, @key, @generator_keys, @target_dir = schema_set_key, key, generator_keys, target_dir
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
        task self.key => ["#{self.namespace_key}:load"] do
          begin
            FileUtils.rm_rf(self.target_dir) if self.clobber_dir
            Domgen.generate(self.schema_set_key, self.target_dir, self.generator_keys, self.filter)
          rescue => e
            print "An error occurred invoking the generator\n"
            puts $@
            raise e
          end
        end
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
          rescue => e
            print "An error occurred loading schema\n"
            puts $@
            raise e
          end
        end
      end
    end
  end
end