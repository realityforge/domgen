module Domgen
  module JAXB
    class JaxbStructField < Domgen.ParentedElement(:field)
      include Domgen::Java::EEJavaCharacteristic

      attr_writer :name

      def name
        @name || (field.struct? && field.collection_type != :none ? Domgen::Naming.pluralize(field.name) : field.name)
      end

      attr_writer :xml_name

      def xml_name
        @xml_name || Domgen::Naming.xmlize(field.name)
      end

      attr_writer :required

      def required?
        @required.nil? ? !field.nullable? : @required
      end

      attr_writer :element

      def element?
        @element.nil? ? false : @element
      end

      attr_accessor :namespace

      protected

      def characteristic
        field
      end
    end

    class JaxbStruct < Domgen.ParentedElement(:struct)
      attr_writer :name

      def name
        @name || struct.name
      end

    def qualified_name
      "#{struct.data_module.jaxb.package}.#{self.name}"
    end

      attr_writer :xml_name

      def xml_name
        @xml_name || Domgen::Naming.xmlize(struct.name)
      end

      attr_accessor :namespace
    end

    class JaxbDataModule < Domgen.ParentedElement(:data_module)
      attr_writer :package

      def package
        @package || "#{data_module.repository.jaxb.package}.#{Domgen::Naming.underscore(data_module.name)}"
      end
    end

    class JaxbPackage < Domgen.ParentedElement(:repository)
      attr_writer :package

      def package
        @package || Domgen::Naming.underscore(repository.name)
      end
    end
  end

  FacetManager.define_facet(:jaxb,
                            Struct => Domgen::JAXB::JaxbStruct,
                            StructField => Domgen::JAXB::JaxbStructField,
                            DataModule => Domgen::JAXB::JaxbPackage,
                            Repository => Domgen::JAXB::JaxbPackage)
end
