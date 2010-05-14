module Domgen
  module Generator
    def self.define_iris_templates(template_set)
      template_set.per_schema << Template.new('iris/module',
                                              '#{schema.java.package.gsub(".","/")}/#{schema.name}Module.java',
                                              'src',
                                              'schema.iris.generate?')
      template_set.per_object_type << Template.new('iris/model',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}Bean.java',
                                                   'src',
                                                   'object_type.iris.generate?')
      template_set.per_schema << Template.new('iris/visitor',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Visitor.java',
                                              'src',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/abstract_visitor',
                                              '#{schema.java.package.gsub(".","/")}/visitor/AbstractVisitor.java',
                                              'src',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Filter.java',
                                              'src',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/abstract_filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/AbstractFilter.java',
                                              'src',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/chain_filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/ChainFilter.java',
                                              'src',
                                              'schema.iris.generate?')
      template_set.per_schema << Template.new('iris/traverser',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Traverser.java',
                                              'src',
                                              'schema.iris.generate?')
    end
  end
end
