module Domgen
  module JAXB
    class JaxbStructField < Domgen.ParentedElement(:field)
      include Domgen::Java::EEJavaCharacteristic

      attr_writer :name

      def name
        @name || (field.collection? ? Domgen::Naming.pluralize(field.name) : field.name)
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

      # default to false for non-collection attributes and true for collection attributes
      def element?
        @element.nil? ? field.collection? : @element
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
      "#{struct.data_module.jaxb.data_type_package}.#{self.name}"
    end

      attr_writer :xml_name

      def xml_name
        return @xml_name if @xml_name
        candidate = Domgen::Naming.xmlize(struct.name)
        return candidate[0,candidate.size-4] if candidate =~ /-dto$/
        return candidate[0,candidate.size-3] if candidate =~ /-vo$/
        candidate
      end

      attr_accessor :namespace
    end

    class JaxbDataModule < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

      protected

      def facet_key
        :jaxb
      end
    end

    class JaxbPackage < Domgen.ParentedElement(:repository)
      include Domgen::Java::ServerJavaApplication
    end
  end

  FacetManager.define_facet(:jaxb,
                            Struct => Domgen::JAXB::JaxbStruct,
                            StructField => Domgen::JAXB::JaxbStructField,
                            DataModule => Domgen::JAXB::JaxbDataModule,
                            Repository => Domgen::JAXB::JaxbPackage)
end
