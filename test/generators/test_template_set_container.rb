require File.expand_path('../../helper', __FILE__)

class Domgen::Generators::TestTemplateSetContainer < Domgen::TestCase
  def test_template_set_container
    assert_equal 0, TestTemplateSetContainer.template_sets.size
    assert_equal false, TestTemplateSetContainer.template_set_by_name?(:foo)
    assert_generator_error('Unable to locate template_set foo') { TestTemplateSetContainer.template_set_by_name(:foo) }

    assert_generator_error("TemplateSet 'iris_entity' defined requirement on template set 'iris_shared' that does not exist.") do
      Domgen::Generators::TemplateSet.new(TestTemplateSetContainer,
                                           :iris_entity,
                                           :required_template_sets => [:iris_shared])
    end

    template_set1 = TestTemplateSetContainer.template_set(:foo)

    assert_equal 1, TestTemplateSetContainer.template_sets.size
    assert_equal true, TestTemplateSetContainer.template_set_by_name?(:foo)
    assert_equal template_set1, TestTemplateSetContainer.template_set_by_name(:foo)

    template_set2 = TestTemplateSetContainer.template_set(:bar => :foo)

    assert_equal 2, TestTemplateSetContainer.template_sets.size
    assert_equal true, TestTemplateSetContainer.template_set_by_name?(:bar)
    assert_equal template_set2, TestTemplateSetContainer.template_set_by_name(:bar)
    assert_equal [:foo], template_set2.required_template_sets

    template_set3 = TestTemplateSetContainer.template_set(:baz => [:foo, :bar])

    assert_equal 3, TestTemplateSetContainer.template_sets.size
    assert_equal true, TestTemplateSetContainer.template_set_by_name?(:baz)
    assert_equal template_set3, TestTemplateSetContainer.template_set_by_name(:baz)
    assert_equal [:foo, :bar], template_set3.required_template_sets
  end
end
