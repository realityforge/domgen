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

      attr_writer :generates_changes

      def generates_changes?
        @generates_changes = parent.persistent? if @generates_changes.nil?
        @generates_changes
      end
    end

    class IrisClass < IrisElement
      attr_accessor :display_name

      attr_writer :preload

      def preload?
        @preload = false if @preload.nil?
        @preload
      end

      attr_writer :generate

      def generate?
        @generate = true if @generate.nil?
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
