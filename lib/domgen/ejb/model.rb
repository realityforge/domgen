module Domgen
  module EJB
    class EjbElement < BaseConfigElement
      attr_reader :parent

      def initialize(parent, options = {}, &block)
        @parent = parent
        super(options, &block)
      end
    end

    class EjbClass < EjbElement
      def service
        self.parent
      end

      attr_writer :local

      def local?
        @local.nil? ? true : @local
      end

      def remote?
        !local?
      end
    end
  end

  class Service
    self.extensions << :ejb

    def ejb
      @ejb ||= Domgen::EJB::EjbClass.new(self)
    end
  end
end
