module Domgen
  module JAXB
    module Helper
      def namespace_annotation_parameter(element)
        return '' unless element.namespace
        ", namespace='#{element.namespace}'"
      end

      def jaxb_field_annotation(field)
        if field.collection?
<<JAVA
   @javax.xml.bind.annotation.XmlElementWrapper( name = "#{Domgen::Naming.pluralize(field.jaxb.xml_name)}", required = #{field.jaxb.required?}#{namespace_annotation_parameter(field.jaxb) })
   @javax.xml.bind.annotation.XmlElement( name = "#{field.jaxb.xml_name}" )
JAVA
        else
          "@javax.xml.bind.annotation.Xml#{field.jaxb.element? ? "Element" : "Attribute" }( name = \"#{field.jaxb.xml_name}\", required = #{field.jaxb.required?}#{namespace_annotation_parameter(field.jaxb) } )"
        end
      end
    end
  end
end
