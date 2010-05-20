module Domgen
  module Generator
    def self.define_iris_templates(template_set)
      template_set.per_object_type << Template.new('iris/model',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}Bean.java',
                                                   'java',
                                                   'object_type.iris.generate?')
      template_set.per_object_type << Template.new('iris/persist_peer',
                                                   '#{object_type.schema.java.package.gsub(".","/")}/persist/#{object_type.java.classname}PersistPeer.java',
                                                   'java',
                                                   'object_type.iris.generate? && object_type.name != :Batch')
      template_set.per_schema << Template.new('iris/xml_generator',
                                              '#{schema.java.package.gsub(".","/")}/#{schema.name}XMLGenerator.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/sync',
                                              '#{schema.java.package.gsub(".","/")}/#{schema.name}Sync.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/codec',
                                              '#{schema.java.package.gsub(".","/")}/#{schema.name}Codec.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/module',
                                              '#{schema.java.package.gsub(".","/")}/#{schema.name}Module.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/validator',
                                              '#{schema.java.package.gsub(".","/")}/#{schema.name}Validator.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/visitor',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Visitor.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/abstract_visitor',
                                              '#{schema.java.package.gsub(".","/")}/visitor/AbstractVisitor.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Filter.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/abstract_filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/AbstractFilter.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/chain_filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/ChainFilter.java',
                                              'java',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/traverser',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Traverser.java',
                                              'java',
                                              'schema.iris.generate?')
    end
  end
end
