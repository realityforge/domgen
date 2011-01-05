module Domgen
  module Docbook
    def self.generate_xml(root)
      h = Generator.new
      h.visit_data_module(root)
      h.doc.target!
    end

    class Generator < Helper
      include Domgen::Docbook::Templates::Attribute
    end
  end
end