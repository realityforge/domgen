require File.expand_path('../../helper', __FILE__)
require File.expand_path('../jpa/model', __FILE__)

class Domgen::Generators::TestStandardArtifactDSL < Domgen::TestCase
  def test_artifact_with_erb_template
    TestTemplateSetContainer.target_manager.target(:entity)

    TestFacetExtension.define_artifacts1

    assert_equal TestTemplateSetContainer.template_sets.size, 1

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true

    template_set = TestTemplateSetContainer.template_set_by_name(:jpa_models)

    assert_equal true, template_set.template_by_name?('jpa_models:mytemplate.java')

    mytemplate = template_set.template_by_name('jpa_models:mytemplate.java')

    assert_equal mytemplate.name, 'jpa_models:mytemplate.java'
    assert_equal mytemplate.output_filename_pattern, 'main/java/#{entity.qualified_name}.java'
    assert_equal template_set, mytemplate.template_set
    assert_equal [:jpa], mytemplate.facets
    assert_equal :entity, mytemplate.target
    assert_equal [], mytemplate.helpers
    assert_equal File.expand_path("#{File.dirname(__FILE__)}/jpa/templates/mytemplate.java.erb"), mytemplate.template_key
    assert_nil mytemplate.guard
    assert_equal({}, mytemplate.extra_data)
  end

  def test_artifact_with_ruby_template
    TestTemplateSetContainer.target_manager.target(:entity)

    TestFacetExtension.define_artifacts2

    assert_equal TestTemplateSetContainer.template_sets.size, 1

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true

    template_set = TestTemplateSetContainer.template_set_by_name(:jpa_models)

    assert_equal true, template_set.template_by_name?('jpa_models:rubytemplate.java')

    mytemplate = template_set.template_by_name('jpa_models:rubytemplate.java')

    assert_equal mytemplate.name, 'jpa_models:rubytemplate.java'
    assert_equal mytemplate.output_filename_pattern, 'main/java/#{entity.qualified_name}.java'
    assert_equal template_set, mytemplate.template_set
    assert_equal [:jpa], mytemplate.facets
    assert_equal :entity, mytemplate.target
    assert_equal [], mytemplate.helpers
    assert_equal File.expand_path("#{File.dirname(__FILE__)}/jpa/templates/rubytemplate.java.rb"), mytemplate.template_key
    assert_nil mytemplate.guard
    assert_equal({}, mytemplate.extra_data)
  end

  def test_artifact_with_options
    TestTemplateSetContainer.target_manager.target(:entity)

    TestFacetExtension.define_artifacts3

    assert_equal TestTemplateSetContainer.template_sets.size, 1

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true

    template_set = TestTemplateSetContainer.template_set_by_name(:jpa_models)

    assert_equal true, template_set.template_by_name?('jpa_models:mytemplate.java')

    mytemplate = template_set.template_by_name('jpa_models:mytemplate.java')

    assert_equal mytemplate.name, 'jpa_models:mytemplate.java'
    assert_equal mytemplate.output_filename_pattern, 'main/java/#{entity.qualified_name}.java'
    assert_equal template_set, mytemplate.template_set
    assert_equal [:jpa, :ee], mytemplate.facets
    assert_equal :entity, mytemplate.target
    assert_equal [TestFacetExtension::MyHelperModule], mytemplate.helpers
    assert_equal File.expand_path("#{File.dirname(__FILE__)}/jpa/templates/mytemplate.java.erb"), mytemplate.template_key
    assert_equal 'entity.jpa.good?', mytemplate.guard
    assert_equal({}, mytemplate.extra_data)
  end

  def test_artifact_with_default_helpers
    TestTemplateSetContainer.target_manager.target(:entity)

    TestTemplateSetContainer.helpers = [TestFacetExtension::MyHelperModule]

    TestFacetExtension.define_artifacts4

    assert_equal TestTemplateSetContainer.template_sets.size, 1

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true

    template_set = TestTemplateSetContainer.template_set_by_name(:jpa_models)

    assert_equal true, template_set.template_by_name?('jpa_models:mytemplate.java')

    mytemplate = template_set.template_by_name('jpa_models:mytemplate.java')

    assert_equal mytemplate.name, 'jpa_models:mytemplate.java'
    assert_equal mytemplate.output_filename_pattern, 'main/java/#{entity.qualified_name}.java'
    assert_equal template_set, mytemplate.template_set
    assert_equal [:jpa], mytemplate.facets
    assert_equal :entity, mytemplate.target
    assert_equal [TestFacetExtension::MyHelperModule], mytemplate.helpers
    assert_equal File.expand_path("#{File.dirname(__FILE__)}/jpa/templates/mytemplate.java.erb"), mytemplate.template_key
    assert_nil mytemplate.guard
    assert_equal({}, mytemplate.extra_data)
  end

  def test_multiple_artifact_definitions
    TestTemplateSetContainer.target_manager.target(:entity)

    TestFacetExtension.define_artifacts5

    assert_equal TestTemplateSetContainer.template_sets.size, 2

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true
    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_qa_models), true

    template_set1 = TestTemplateSetContainer.template_set_by_name(:jpa_models)
    assert_equal 1, template_set1.templates.size
    assert_equal true, template_set1.template_by_name?('jpa_models:mytemplate.java')

    template_set2 = TestTemplateSetContainer.template_set_by_name(:jpa_qa_models)
    assert_equal 2, template_set2.templates.size
    assert_equal true, template_set2.template_by_name?('jpa_qa_models:mytemplate.java')
    assert_equal true, template_set2.template_by_name?('jpa_qa_models:rubytemplate.java')
  end

  def test_artifact_bad_option
    TestTemplateSetContainer.target_manager.target(:entity)

    assert_generator_error("Unknown option ':bad_option' passed to define artifact") do
      TestFacetExtension.define_artifacts6
    end
  end

  def test_java_artifact
    TestTemplateSetContainer.target_manager.target(:entity)

    TestFacetExtension.define_artifacts7

    assert_equal TestTemplateSetContainer.template_sets.size, 1

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true

    template_set = TestTemplateSetContainer.template_set_by_name(:jpa_models)

    assert_equal true, template_set.template_by_name?('jpa_models:mytemplate.java')

    mytemplate = template_set.template_by_name('jpa_models:mytemplate.java')

    assert_equal mytemplate.name, 'jpa_models:mytemplate.java'
    assert_equal mytemplate.output_filename_pattern, 'main/java/#{entity.jpa.qualified_mytemplate_name.gsub(".","/")}.java'
    assert_equal template_set, mytemplate.template_set
    assert_equal [:jpa], mytemplate.facets
    assert_equal :entity, mytemplate.target
    assert_equal [], mytemplate.helpers
    assert_equal File.expand_path("#{File.dirname(__FILE__)}/jpa/templates/mytemplate.java.erb"), mytemplate.template_key
    assert_nil mytemplate.guard
    assert_equal({}, mytemplate.extra_data)
  end

  def test_test_java_artifact
    TestTemplateSetContainer.target_manager.target(:entity)

    TestFacetExtension.define_artifacts8

    assert_equal TestTemplateSetContainer.template_sets.size, 1

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true

    template_set = TestTemplateSetContainer.template_set_by_name(:jpa_models)

    assert_equal true, template_set.template_by_name?('jpa_models:mytemplate.java')

    mytemplate = template_set.template_by_name('jpa_models:mytemplate.java')

    assert_equal mytemplate.name, 'jpa_models:mytemplate.java'
    assert_equal mytemplate.output_filename_pattern, 'test/java/#{entity.jpa.qualified_mytemplate_name.gsub(".","/")}.java'
    assert_equal template_set, mytemplate.template_set
    assert_equal [:jpa], mytemplate.facets
    assert_equal :entity, mytemplate.target
    assert_equal [], mytemplate.helpers
    assert_equal File.expand_path("#{File.dirname(__FILE__)}/jpa/templates/mytemplate.java.erb"), mytemplate.template_key
    assert_nil mytemplate.guard
    assert_equal({}, mytemplate.extra_data)
  end

  def test_main_java_artifact
    TestTemplateSetContainer.target_manager.target(:entity)

    TestFacetExtension.define_artifacts9

    assert_equal TestTemplateSetContainer.template_sets.size, 1

    assert_equal TestTemplateSetContainer.template_set_by_name?(:jpa_models), true

    template_set = TestTemplateSetContainer.template_set_by_name(:jpa_models)

    assert_equal true, template_set.template_by_name?('jpa_models:mytemplate.java')

    mytemplate = template_set.template_by_name('jpa_models:mytemplate.java')

    assert_equal mytemplate.name, 'jpa_models:mytemplate.java'
    assert_equal mytemplate.output_filename_pattern, 'main/java/#{entity.jpa.qualified_mytemplate_name.gsub(".","/")}.java'
    assert_equal template_set, mytemplate.template_set
    assert_equal [:jpa], mytemplate.facets
    assert_equal :entity, mytemplate.target
    assert_equal [], mytemplate.helpers
    assert_equal File.expand_path("#{File.dirname(__FILE__)}/jpa/templates/mytemplate.java.erb"), mytemplate.template_key
    assert_nil mytemplate.guard
    assert_equal({}, mytemplate.extra_data)
  end
end
