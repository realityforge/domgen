require File.expand_path('../../helper', __FILE__)

class Domgen::Generators::TestTemplateSet < Domgen::TestCase
  def test_template_set
    TestTemplateSetContainer.target_manager.target(:component)

    assert_generator_error("TemplateSet 'iris_entity' defined requirement on template set 'iris_shared' that does not exist.") do
      Domgen::Generators::TemplateSet.new(TestTemplateSetContainer,
                                           :iris_entity,
                                           :required_template_sets => [:iris_shared])
    end

    template_set1 = Domgen::Generators::TemplateSet.new(TestTemplateSetContainer, :iris_shared)

    template_set2 =
      Domgen::Generators::TemplateSet.new(TestTemplateSetContainer,
                                           :iris_entity,
                                           :required_template_sets => [:iris_shared],
                                           :description => 'Templates that generate iris entities')

    assert_equal :iris_shared, template_set1.name
    assert_equal [], template_set1.required_template_sets
    assert_equal 0, template_set1.templates.size
    assert_nil template_set1.description

    assert_equal :iris_entity, template_set2.name
    assert_equal [:iris_shared], template_set2.required_template_sets
    assert_equal 0, template_set2.templates.size
    assert_equal 'Templates that generate iris entities', template_set2.description

    template = Domgen::Generators::ErbTemplate.new(template_set2,
                                                    [],
                                                    :component,
                                                    'jpa/templates/mytemplate.java.erb',
                                                    'src/main/#{component.name}',
                                                    [],
                                                    {})
    assert_equal 1, template_set2.templates.size
    assert_equal true, template_set2.template_by_name?(template.name)
    assert_equal template, template_set2.template_by_name(template.name)

    assert_generator_error('Template already exists with specified name iris_entity:mytemplate.java') do
      Domgen::Generators::ErbTemplate.new(template_set2,
                                           [],
                                           :component,
                                           'jpa/templates/mytemplate.java.erb',
                                           'src/main/#{component.name}',
                                           [],
                                           {})
    end
  end
end
