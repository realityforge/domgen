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
      attr_writer :inverse_sorter

      def inverse_sorter
        @inverse_sorter = 'iris.model.sorters.ToLabelComparator' if @inverse_sorter.nil?
        @inverse_sorter
      end

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

      attr_writer :fetch_type

      def fetch_type?
        @fetch_type = :lazy if @fetch_type.nil?
        @fetch_type
      end

      def lazy_fetch_type?
        fetch_type? == :lazy
      end

      def eager_fetch_type?
        fetch_type? == :eager
      end

      attr_writer :client_side

      def client_side?
        @client_side = true if @client_side.nil?
        @client_side
      end
    end

    class Criterion < IrisElement
      attr_reader :name
      attr_accessor :sql
      attr_accessor :parameter_type

      def initialize(parent, name, parameter_type, sql, options = {}, & block)
        @name, @parameter_type, @sql = name, parameter_type, sql
        super(parent, options, & block)
      end

      def code_based?
        @sql.nil?
      end

      def java_parameter_type
        return "java.lang.String" if parameter_type == :string
        return "java.sql.Timestamp" if parameter_type == :datetime
        return parameter_type 
      end
    end

    class IrisClass < IrisElement
      def initialize(parent, options = {}, &block)
        @criteria = Domgen::OrderedHash.new
        super(parent, options, &block)
      end

      def classname
        "#{parent.java.fully_qualified_name}Bean"
      end

      def criteria
        @criteria.values
      end

      def criterion(name, parameter_type, sql = nil, options = {}, &block)
        raise "Criterion with name #{name} already exists for object type #{parent.name}" if @criteria[name.to_s]
        query = Criterion.new(self, name, parameter_type, sql, options, &block)
        @criteria[name.to_s] = query
        query
      end

      attr_writer :preload

      def preload?
        @preload = false if @preload.nil?
        @preload
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
