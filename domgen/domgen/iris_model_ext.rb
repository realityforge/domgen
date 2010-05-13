module Domgen
  module Iris
    class IrisElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class IrisAttribute < IrisElement
      attr_accessor :inverse_sorter

      # Is this attribute one of the magic ones that should not be handled by generator
      attr_writer :runtime_managed

      def runtime_managed?
        @runtime_managed = false if @runtime_managed.nil?
        @runtime_managed
      end


      attr_writer :traversable

      def traversable?
        @traversable = false if @traversable.nil?
        @traversable
      end

      attr_writer :managed

      def managed?
        @managed = false if @managed.nil?
        @managed
      end

      attr_writer :client_side

      def client_side?
        @client_side = true if @client_side.nil?
        @client_side
      end
    end

    class Query < IrisElement
      attr_reader :name
      attr_accessor :sql
      attr_accessor :parameter_type

      def initialize(parent, name, parameter_type, sql, options = {}, & block)
        @name, @parameter_type, @sql = name, parameter_type, sql
        super(parent, options, & block)
      end

      def java_parameter_type
        return "java.lang.String" if parameter_type == :string
        return "java.sql.Timestamp" if parameter_type == :datetime
        raise "Unknwon parameter type #{parameter_type} for query #{name} on #{parent.parent.name}"
      end
    end

    class IrisClass < IrisElement
      def initialize(parent, options = {}, &block)
        @queries = Domgen::OrderedHash.new
        super(parent, options, &block)
      end

      def queries
        @queries.values
      end

      def query(name, parameter_type, sql, options = {}, &block)
        raise "Query with name #{name} already exists for object type #{parent.name}" if @queries[name.to_s]
        query = Query.new(self, name, parameter_type, sql, options, &block)
        @queries[name.to_s] = query
        query
      end

      attr_writer :preload

      def preload?
        @preload = false if @preload.nil?
        @preload
      end

      attr_writer :generate

      def generate?
        @generate = parent.schema.iris.generate? if @generate.nil?
        @generate
      end

      attr_writer :metadata

      def metadata?
        @metadata = false if @metadata.nil?
        @metadata
      end

      attr_writer :metadata_that_can_change

      def metadata_that_can_change?
        @metadata_that_can_change = false if @metadata_that_can_change.nil?
        @metadata_that_can_change
      end

      attr_writer :synchronized

      def synchronized?
        @synchronized = true if @synchronized.nil?
        @synchronized
      end

      attr_writer :client_side

      def client_side?
        @client_side = true if @client_side.nil?
        @client_side
      end
    end

    class IrisModule < IrisElement
      attr_writer :generate

      def generate?
        @generate = false if @generate.nil?
        @generate
      end
    end
  end

  class Attribute
    def iris
      @iris = Domgen::Iris::IrisAttribute.new(self) unless @iris
      @iris
    end
  end

  class ObjectType
    def iris
      @iris = Domgen::Iris::IrisClass.new(self) unless @iris
      @iris
    end
  end

  class Schema
    def iris
      @iris = Domgen::Iris::IrisModule.new(self) unless @iris
      @iris
    end
  end
end
