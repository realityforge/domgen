module Domgen
  module Generator
    def self.define_docbook_templates
      [XmlTemplate.new(:data_module, Domgen::Xml::Templates::Xml, '#{data_module.name}.doc.xml', [Domgen::Xml::Helper])]
    end
  end
end