module Domgen
  module Generator
    def self.define_docbook_templates
      [InlineTemplate.new(:data_module, 'Domgen::Docbook.generate_xml(data_module)', '#{data_module.name}.doc.xml')]
    end
  end
end