module Domgen
  module Generator
    def self.define_iris_templates
      schema_file_prefix = 'java/#{schema.java.package.gsub(".","/")}/#{schema.name}'
      visitor_pkg_prefix = 'java/#{schema.java.package.gsub(".","/")}/visitor/'
      helpers = [IrisHelper]
      [
          Template.new(:object_type,
                       'iris/model',
                       'java/#{object_type.java.fully_qualified_name.gsub(".","/")}Bean.java',
                       helpers),
          Template.new(:object_type,
                       'iris/persist_peer',
                       'java/#{object_type.schema.java.package.gsub(".","/")}/persist/#{object_type.java.classname}PersistPeer.java',
                       helpers,
                       'object_type.name != :Batch'),
          Template.new(:schema, 'iris/xml_generator', "#{schema_file_prefix}XMLGenerator.java", helpers),
          Template.new(:schema, 'iris/sync', "#{schema_file_prefix}Sync.java", helpers),
          Template.new(:schema, 'iris/codec', "#{schema_file_prefix}Codec.java", helpers),
          Template.new(:schema, 'iris/module', "#{schema_file_prefix}Module.java", helpers),
          Template.new(:schema, 'iris/validator', "#{schema_file_prefix}Validator.java", helpers),
          Template.new(:schema, 'iris/visitor', "#{visitor_pkg_prefix}Visitor.java", helpers),
          Template.new(:schema, 'iris/abstract_visitor', "#{visitor_pkg_prefix}AbstractVisitor.java", helpers),
          Template.new(:schema, 'iris/filter', "#{visitor_pkg_prefix}Filter.java", helpers),
          Template.new(:schema, 'iris/abstract_filter', "#{visitor_pkg_prefix}AbstractFilter.java", helpers),
          Template.new(:schema, 'iris/chain_filter', "#{visitor_pkg_prefix}ChainFilter.java", helpers),
          Template.new(:schema, 'iris/traverser', "#{visitor_pkg_prefix}Traverser.java", helpers),
      ]
    end
  end
end
