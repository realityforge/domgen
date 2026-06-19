require File.expand_path('../../helper', __FILE__)

class Domgen::Generators::TestErbTemplate < Domgen::TestCase

  class SimpleModel
    def name
      'SimpleModel'
    end

    def facet_enabled?(facet)
      true
    end
  end

  def test_erb_template
    template_set = Domgen::Generators::TemplateSet.new(TestTemplateSetContainer, 'foo')

    output_filename_pattern = 'main/java/#{component.name}.java'
    template_filename = File.expand_path(File.dirname(__FILE__) + '/jpa/templates/mytemplate.java.erb')
    TestTemplateSetContainer.target_manager.target(:component)

    template1 = Domgen::Generators::ErbTemplate.new(template_set, [], :component, template_filename, output_filename_pattern, [], {})

    assert_equal output_filename_pattern, template1.output_filename_pattern
    assert_equal output_filename_pattern, template1.output_path
    assert_equal template_set, template1.template_set
    assert_equal [], template1.facets
    assert_equal :component, template1.target
    assert_equal [], template1.helpers
    assert_equal template_filename, template1.template_key
    assert_nil template1.guard
    assert_equal({}, template1.extra_data)
    assert_equal 'foo:mytemplate.java', template1.name

    target_basedir = "#{temp_dir}/generated/erb_template"
    target_filename = "#{target_basedir}/main/java/SimpleModel.java"
    other_filename = "#{target_basedir}/main/java/Other.java"
    unprocessed_files = %W(#{target_filename} #{other_filename})
    assert_equal false, File.exist?(target_filename)
    template1.generate(target_basedir, SimpleModel.new, unprocessed_files)
    assert_equal true, File.exist?(target_filename)
    assert_equal 1, unprocessed_files.size

    assert_equal <<JAVA, IO.read(target_filename)
/* DO NOT EDIT: File is auto-generated */

@javax.annotation.Generated( "reality-generators" )
public class SimpleModel
{
}
JAVA
  end
end
