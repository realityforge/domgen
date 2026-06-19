require File.expand_path('../../helper', __FILE__)
require 'date'

class Domgen::Generators::TestGenerator < Domgen::TestCase

  class Attribute < Domgen.base_element(:name => true, :container_key => :entity)
    def qualified_name
      "#{entity.qualified_name}.#{name}"
    end
  end

  class Entity < Domgen.base_element(:name => true, :container_key => :repository)
    def qualified_name
      "#{repository.name}.#{name}"
    end

    def attribute(name, options = {}, &block)
      attribute_map[name.to_s] = Attribute.new(self, name, options, &block)
    end

    def attributes
      attribute_map.values
    end

    def attribute_map
      @attribute_map ||= {}
    end
  end

  class PersistenceUnit < Domgen.base_element(:name => true, :container_key => :jpa_repository)
  end

  class JpaRepository < Domgen.base_element(:container_key => :repository)

    def unit(name, options = {}, &block)
      unit_map[name.to_s] = PersistenceUnit.new(self, name, options, &block)
    end

    def units
      unit_map.values
    end

    def unit_map
      @unit_map ||= {}
    end
  end

  class Repository < Domgen.base_element(:name => true)
    def entity(name, options = {}, &block)
      entity_map[name.to_s] = Entity.new(self, name, options, &block)
    end

    def entities
      entity_map.values
    end

    def entity_map
      @entity_map ||= {}
    end

    def facet_enabled?(facet)
      facet == :jpa ? !!self.jpa : false
    end

    def jpa
      @jpa ||= nil
    end

    def enable_jpa!
      @jpa = JpaRepository.new(self)
    end
  end

  def test_collect_generation_targets
    repository = Repository.new(:MyRepo) do |r|
      r.entity(:MyEntityA) do |e|
        e.attribute(:MyAttr1)
        e.attribute(:MyAttr2)
      end

      r.entity(:MyEntityB) do |e|
        e.attribute(:MyAttr3)
        e.attribute(:MyAttr4)
      end
    end

    TestTemplateSetContainer.target_manager.target(:repository)
    TestTemplateSetContainer.target_manager.target(:entity, :repository)
    TestTemplateSetContainer.target_manager.target(:attribute, :entity)
    TestTemplateSetContainer.target_manager.target(:unit, :repository, :facet_key => :jpa)

    targets = {}
    TestTemplateSetContainer.generator.send(:collect_generation_targets, :repository, repository, repository, targets)

    assert_equal true, targets.include?(:repository)
    assert_equal true, targets.include?(:entity)
    assert_equal true, targets.include?(:attribute)
    assert_equal 3, targets.size

    assert_equal 1, targets[:repository].size
    assert_equal 2, targets[:entity].size
    assert_equal 4, targets[:attribute].size

    assert_equal :MyRepo, targets[:repository][0][0].name
    assert_equal :MyRepo, targets[:repository][0][1].name
    assert_equal 'MyRepo.MyEntityA', targets[:entity][0][0].qualified_name
    assert_equal 'MyRepo.MyEntityA', targets[:entity][0][1].qualified_name
    assert_equal 'MyRepo.MyEntityB', targets[:entity][1][0].qualified_name
    assert_equal 'MyRepo.MyEntityB', targets[:entity][1][1].qualified_name
    assert_equal 'MyRepo.MyEntityA.MyAttr1', targets[:attribute][0][0].qualified_name
    assert_equal 'MyRepo.MyEntityA.MyAttr1', targets[:attribute][0][1].qualified_name
    assert_equal 'MyRepo.MyEntityA.MyAttr2', targets[:attribute][1][0].qualified_name
    assert_equal 'MyRepo.MyEntityA.MyAttr2', targets[:attribute][1][1].qualified_name
    assert_equal 'MyRepo.MyEntityB.MyAttr3', targets[:attribute][2][0].qualified_name
    assert_equal 'MyRepo.MyEntityB.MyAttr3', targets[:attribute][2][1].qualified_name
    assert_equal 'MyRepo.MyEntityB.MyAttr4', targets[:attribute][3][0].qualified_name
    assert_equal 'MyRepo.MyEntityB.MyAttr4', targets[:attribute][3][1].qualified_name

    repository.enable_jpa!

    targets = {}
    TestTemplateSetContainer.generator.send(:collect_generation_targets, :repository, repository, repository, targets)

    # No units have been defined so no extra targets
    assert_equal 3, targets.size

    repository.jpa.unit(:MyUnit1)
    repository.jpa.unit(:MyUnit2)

    targets = {}
    TestTemplateSetContainer.generator.send(:collect_generation_targets, :repository, repository, repository, targets)

    assert_equal true, targets.include?(:repository)
    assert_equal true, targets.include?(:entity)
    assert_equal true, targets.include?(:attribute)
    assert_equal true, targets.include?(:'jpa.unit')
    assert_equal 4, targets.size

    assert_equal 1, targets[:repository].size
    assert_equal 2, targets[:entity].size
    assert_equal 4, targets[:attribute].size
    assert_equal 2, targets[:'jpa.unit'].size

    assert_equal :MyRepo, targets[:'jpa.unit'][0][0].name
    assert_equal :MyUnit1, targets[:'jpa.unit'][0][1].name
    assert_equal :MyRepo, targets[:'jpa.unit'][1][0].name
    assert_equal :MyUnit2, targets[:'jpa.unit'][1][1].name
  end

  class RepositoryTemplate < Domgen::Generators::SingleFileOutputTemplate
    def render_to_string(context_binding)
      eval('"Repository: #{repository.name}"', context_binding)
    end
  end

  class EntityTemplate < Domgen::Generators::SingleFileOutputTemplate
    def render_to_string(context_binding)
      eval('"Entity: #{entity.name}"', context_binding)
    end
  end

  class AttributeTemplate < Domgen::Generators::SingleFileOutputTemplate
    def render_to_string(context_binding)
      eval('"Attribute: #{attribute.name}"', context_binding)
    end
  end

  class UnitTemplate < Domgen::Generators::SingleFileOutputTemplate
    def render_to_string(context_binding)
      eval('"Unit: #{unit.name}"', context_binding)
    end
  end

  def test_generate
    repository = Repository.new(:MyRepo) do |r|
      r.entity(:MyEntityA) do |e|
        e.attribute(:MyAttr1)
        e.attribute(:MyAttr2)
      end

      r.entity(:MyEntityB) do |e|
        e.attribute(:MyAttr3)
        e.attribute(:MyAttr4)
      end
    end

    TestTemplateSetContainer.target_manager.target(:repository)
    TestTemplateSetContainer.target_manager.target(:entity, :repository)
    TestTemplateSetContainer.target_manager.target(:attribute, :entity)
    TestTemplateSetContainer.target_manager.target(:unit, :repository, :facet_key => :jpa)

    template_set = TestTemplateSetContainer.template_set(:test) do |t|
      RepositoryTemplate.new(t, [], :repository, 'repository.java', 'main/java/#{repository.name}.java')

      EntityTemplate.new(t, [], :entity, 'entity.java', 'main/java/#{entity.qualified_name.gsub(".","/")}.java', [], :guard => 'entity.qualified_name == "MyRepo.MyEntityB"')
      AttributeTemplate.new(t, [], :attribute, 'attribute.java', 'main/java/#{attribute.qualified_name.gsub(".","/")}.java')
      UnitTemplate.new(t, [], :'jpa.unit', 'unit.java', 'main/java/units/#{unit.name.gsub(".","/")}.java', [], {})
    end

    target_directory = "#{temp_dir}/generated/erb_template"

    FileUtils.mkdir_p "#{target_directory}/some/dir/to/delete"
    FileUtils.mkdir_p "#{target_directory}/main/java"
    FileUtils.touch "#{target_directory}/main/java/Touched.java"
    repo_file = "#{target_directory}/main/java/MyRepo.java"
    File.open(repo_file, 'wb') do |f|
      f.write 'Repository: MyRepo'
    end
    File.utime(File.atime(repo_file), DateTime.new(2001, 2, 3).to_time, repo_file)
    original_mtime = File.mtime(repo_file)

    filter = Proc.new { |artifact_type, artifact| artifact_type != :attribute || %w(MyAttr1 MyAttr2).include?(artifact.name.to_s) }
    TestTemplateSetContainer.generator.
      generate(:repository, repository, target_directory, template_set.templates, filter)

    assert_equal false, File.directory?("#{target_directory}/some")
    assert_equal false, File.exist?("#{target_directory}/main/java/Touched.java")
    assert_equal true, File.directory?("#{target_directory}/main/java")
    assert_equal true, File.exist?(repo_file)
    assert_equal 'Repository: MyRepo', IO.read(repo_file)

    # Ensure the file is not updated if contents identical
    assert_equal original_mtime, File.mtime(repo_file)

    # The guard says no for next element
    assert_equal false, File.exist?("#{target_directory}/main/java/MyRepo/MyEntityA.java")

    assert_equal true, File.exist?("#{target_directory}/main/java/MyRepo/MyEntityB.java")
    assert_equal 'Entity: MyEntityB', IO.read("#{target_directory}/main/java/MyRepo/MyEntityB.java")

    assert_equal true, File.exist?("#{target_directory}/main/java/MyRepo/MyEntityA/MyAttr1.java")
    assert_equal 'Attribute: MyAttr1', IO.read("#{target_directory}/main/java/MyRepo/MyEntityA/MyAttr1.java")

    assert_equal true, File.exist?("#{target_directory}/main/java/MyRepo/MyEntityA/MyAttr2.java")
    assert_equal 'Attribute: MyAttr2', IO.read("#{target_directory}/main/java/MyRepo/MyEntityA/MyAttr2.java")

    # The filters says no
    assert_equal false, File.exist?("#{target_directory}/main/java/MyRepo/MyEntityB/MyAttr3.java")
    assert_equal false, File.exist?("#{target_directory}/main/java/MyRepo/MyEntityB/MyAttr4.java")
  end

  class Repository2 < Domgen.base_element(:name => true)
      def pre_generate
        @pre_generate_called = true
      end

      def pre_generate_called?
        @pre_generate_called ||= false
      end
  end

  class Repository2Template < Domgen::Generators::SingleFileOutputTemplate
    def render_to_string(context_binding)
      eval('"Repository: #{repository2.name}"', context_binding)
    end
  end

  def test_generate_with_pre_generate_hook
    repository = Repository2.new(:MyRepo)

    TestTemplateSetContainer.target_manager.target(:repository2)

    template_set = TestTemplateSetContainer.template_set(:test) do |t|
      Repository2Template.new(t, [], :repository2, 'repository.java', 'main/java/#{repository2.name}.java')
    end

    target_directory = "#{temp_dir}/generated/erb_template"

    # Call toString on template name to ensure it is possible to pass string in
    TestTemplateSetContainer.generator.
      generate(:repository2, repository, target_directory, [template_set.name.to_s], nil)

    repo_file = "#{target_directory}/main/java/MyRepo.java"

    assert_equal true, repository.pre_generate_called?
    assert_equal true, File.directory?("#{target_directory}/main/java")
    assert_equal true, File.exist?(repo_file)
    assert_equal 'Repository: MyRepo', IO.read(repo_file)
  end

  def test_load_templates_from_template_sets

    TestTemplateSetContainer.target_manager.target(:repository)
    TestTemplateSetContainer.target_manager.target(:entity, :repository)
    TestTemplateSetContainer.target_manager.target(:attribute, :entity)
    TestTemplateSetContainer.target_manager.target(:unit, :repository, :facet_key => :jpa)

    TestTemplateSetContainer.template_set(:template_set_1) do |template_set|
      RepositoryTemplate.new(template_set, [], :repository, 'repository1.java', 'main/java/#{repository.name}1.java')

      EntityTemplate.new(template_set, [], :entity, 'entity.java', 'main/java/#{entity.qualified_name.gsub(".","/")}.java', [], :guard => 'entity.qualified_name == "MyRepo.MyEntityB"')
      AttributeTemplate.new(template_set, [], :attribute, 'attribute.java', 'main/java/#{attribute.qualified_name.gsub(".","/")}.java')
      UnitTemplate.new(template_set, [], :'jpa.unit', 'unit.java', 'main/java/units/#{unit.name.gsub(".","/")}.java', [], {})
    end

    TestTemplateSetContainer.template_set(:template_set_2) do |template_set|
      RepositoryTemplate.new(template_set, [], :repository, 'repository2.java', 'main/java/#{repository.name}2.java')
    end

    TestTemplateSetContainer.template_set(:template_set_3) do |template_set|
      RepositoryTemplate.new(template_set, [], :repository, 'repository3.java', 'main/java/#{repository.name}3.java')
    end

    TestTemplateSetContainer.template_set(:template_set_4) do |template_set|
      RepositoryTemplate.new(template_set, [], :repository, 'repository4.java', 'main/java/#{repository.name}3.java')

      AttributeTemplate.new(template_set, [], :attribute, 'attribute4.java', 'main/java/#{attribute.qualified_name.gsub(".","/")}4.java')
    end

    template_set_keys = [:template_set_1, 'template_set_4']
    templates = TestTemplateSetContainer.generator.load_templates_from_template_sets(template_set_keys)

    assert_equal 6, templates.size
    assert_equal %w(template_set_1:attribute.java template_set_1:entity.java template_set_1:repository1.java template_set_1:unit.java template_set_4:attribute4.java template_set_4:repository4.java),
                 templates.collect{|t| t.name}.sort

  end
end
