require File.expand_path('../../helper', __FILE__)

class Domgen::Generators::TestStandardTemplateSet < Domgen::TestCase
  def test_template_set
    TestTemplateSetContainer.target_manager.target(:component)

    template_set =
      Domgen::Generators::StandardTemplateSet.new(TestTemplateSetContainer,
                                                   :iris_entity,
                                                   :description => 'Templates that generate iris entities') do |t|

        t.erb_template([], :component, 'jpa/templates/mytemplate.java.erb', 'src/main/#{component.name}')
        t.ruby_template([], :component, 'jpa/templates/rubytemplate.java.rb', 'src/main/#{component.name}2')
      end


    assert_equal :iris_entity, template_set.name
    assert_equal [], template_set.required_template_sets
    assert_equal 2, template_set.templates.size
    assert_equal 'Templates that generate iris entities', template_set.description
    assert_equal true, template_set.template_by_name?('iris_entity:rubytemplate.java')
    assert_equal true, template_set.template_by_name?('iris_entity:mytemplate.java')
  end
end
