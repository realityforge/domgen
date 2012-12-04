module Domgen
  module Generator
    module JMS
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:jms]
      HELPERS = [Domgen::Java::Helper, Domgen::JAXB::Helper]
    end
  end
end
Domgen.template_set(:jms => []) do |template_set|
  template_set.template(Domgen::Generator::JMS::FACETS,
                        :method,
                        "#{Domgen::Generator::JMS::TEMPLATE_DIRECTORY}/mdb.java.erb",
                        'main/java/#{method.jms.qualified_mdb_name.gsub(".","/")}.java',
                        Domgen::Generator::JMS::HELPERS)
end
