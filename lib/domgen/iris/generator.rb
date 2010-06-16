module Domgen
  module Generator
    def self.define_iris_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      schema_file_prefix = 'java/#{schema.java.package.gsub(".","/")}/#{schema.name}'
      visitor_pkg_prefix = 'java/#{schema.java.package.gsub(".","/")}/visitor/'
      helpers = [Domgen::Iris::Helper]
      [
          Template.new(:object_type,
                       "#{template_dir}/model.erb",
                       'java/#{object_type.java.fully_qualified_name.gsub(".","/")}Bean.java',
                       helpers),
          Template.new(:object_type,
                       "#{template_dir}/persist_peer.erb",
                       'java/#{object_type.schema.java.package.gsub(".","/")}/persist/#{object_type.java.classname}PersistPeer.java',
                       helpers,
                       'object_type.name != :Batch'),
          Template.new(:schema, "#{template_dir}/xml_generator.erb", "#{schema_file_prefix}XMLGenerator.java", helpers),
          Template.new(:schema, "#{template_dir}/sync.erb", "#{schema_file_prefix}Sync.java", helpers),
          Template.new(:schema, "#{template_dir}/codec.erb", "#{schema_file_prefix}Codec.java", helpers),
          Template.new(:schema, "#{template_dir}/module.erb", "#{schema_file_prefix}Module.java", helpers),
          Template.new(:schema, "#{template_dir}/validator.erb", "#{schema_file_prefix}Validator.java", helpers),
          Template.new(:schema, "#{template_dir}/visitor.erb", "#{visitor_pkg_prefix}Visitor.java", helpers),
          Template.new(:schema, "#{template_dir}/abstract_visitor.erb", "#{visitor_pkg_prefix}AbstractVisitor.java", helpers),
          Template.new(:schema, "#{template_dir}/filter.erb", "#{visitor_pkg_prefix}Filter.java", helpers),
          Template.new(:schema, "#{template_dir}/abstract_filter.erb", "#{visitor_pkg_prefix}AbstractFilter.java", helpers),
          Template.new(:schema, "#{template_dir}/chain_filter.erb", "#{visitor_pkg_prefix}ChainFilter.java", helpers),
          Template.new(:schema, "#{template_dir}/traverser.erb", "#{visitor_pkg_prefix}Traverser.java", helpers),
      ]
    end
  end
end
