module Domgen
  module Generator
    def self.define_docbook_templates
      [XmlTemplate.new(:repository, Domgen::Xml::Templates::Xml, '#{repository.name}.xml', [Domgen::Xml::Helper])]
    end
  end
end