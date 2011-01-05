module Domgen
  module Generator
    def self.define_docbook_templates
      [XmlTemplate.new(:data_module, Domgen::Docbook::Templates::Attribute, '#{data_module.name}.doc.xml', [Domgen::Docbook::Helper])]
    end
  end
end