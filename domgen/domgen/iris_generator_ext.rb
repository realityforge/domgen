module Domgen
  module Generator
    def self.define_iris_templates(template_set)
      template_set.per_object_type << Template.new('iris/model',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}Bean.java',
                                                   'iris',
                                                   'object_type.iris.generate?')
      template_set.per_schema << Template.new('iris/visitor',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Visitor.java',
                                              'iris')
      template_set.per_schema << Template.new('iris/abstract_visitor',
                                              '#{schema.java.package.gsub(".","/")}/visitor/AbstractVisitor.java',
                                              'iris')
      template_set.per_schema << Template.new('iris/filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Filter.java',
                                              'iris')
      template_set.per_schema << Template.new('iris/abstract_filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/AbstractFilter.java',
                                              'iris')
      template_set.per_schema << Template.new('iris/chain_filter',
                                              '#{schema.java.package.gsub(".","/")}/visitor/ChainFilter.java',
                                              'iris')
      template_set.per_schema << Template.new('iris/traverser',
                                              '#{schema.java.package.gsub(".","/")}/visitor/Traverser.java',
                                              'iris')
    end
  end
end
