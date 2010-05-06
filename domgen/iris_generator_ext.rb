module Domgen
  module Generator
    def self.define_iris_templates(template_set)
      template_set.per_object_type << Template.new('iris/model',
                                                   '#{object_type.java.fully_qualified_name.gsub(".","/")}Bean.java',
                                                   'iris')
    end
  end
end
