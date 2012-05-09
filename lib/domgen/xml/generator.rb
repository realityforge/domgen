Domgen.template_set(:xml) do |template_set|
  template_set.xml_template([],
                            :repository,
                            Domgen::Xml::Templates::Xml,
                            '#{repository.name}.xml',
                            [Domgen::Xml::Helper])
end