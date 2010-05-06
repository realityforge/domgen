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
    end

    class IrisClass < IrisElement
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
