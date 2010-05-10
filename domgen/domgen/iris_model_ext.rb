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

      attr_writer :traversable

      def traversable?
        @traversable = false if @traversable.nil?
        @traversable
      end
    end

    class IrisClass < IrisElement
      attr_accessor :metadata_that_can_change
      attr_accessor :display_name
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
end
