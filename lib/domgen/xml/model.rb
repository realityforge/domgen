module Domgen
  module XML

    def self.include_xml(type, parent_key)
      type.class_eval(<<-RUBY)
      attr_writer :name

      def name
        @name || Domgen::Naming.xmlize(#{parent_key}.name)
      end

      attr_accessor :namespace
      RUBY
    end

    class XmlStructField < Domgen.ParentedElement(:field)
      Domgen::XML.include_xml(self, :field)

      def component_name
        Domgen::Naming.xmlize(field.component_name)
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
    end

    class XmlStruct < Domgen.ParentedElement(:struct)
      Domgen::XML.include_xml(self, :struct)

      # Override name to strip out DTO/VO suffix
      def name
        return @name if @name
        candidate = Domgen::Naming.xmlize(struct.name)
        return candidate[0, candidate.size-4] if candidate =~ /-dto$/
        return candidate[0, candidate.size-3] if candidate =~ /-vo$/
        candidate
      end
    end

    class XmlEnumeration < Domgen.ParentedElement(:enumeration)
      Domgen::XML.include_xml(self, :enumeration)
    end
  end

  FacetManager.define_facet(:xml,
                            Struct => Domgen::XML::XmlStruct,
                            StructField => Domgen::XML::XmlStructField,
                            EnumerationSet => Domgen::XML::XmlEnumeration)
end
