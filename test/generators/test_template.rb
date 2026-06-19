require File.expand_path('../../helper', __FILE__)

class Domgen::Generators::TestTemplate < Domgen::TestCase
  module MyHelper
    def a
      'A'
    end

    def b
      'B'
    end
  end

  class SimpleModel
    def name
      'SimpleModel'
    end

    def facet_enabled?(facet)
      true
    end
  end

  class SimpleModel2
    def name
      'SimpleModel'
    end

    def facet_enabled?(facet)
      false
    end
  end

  class ComplexModel
    def name
      'ComplexModel'
    end

    def qualified_name
      'Module.ComplexModel'
    end
  end

  class TestTemplate < Domgen::Generators::Template
    def output_path
      'main/java/com/biz/foo'
    end

    def generate!(target_basedir, element, unprocessed_files)
      # Clear the unprocessed files so test can determine this method is reached
      unprocessed_files.clear
    end
  end

  def test_template
    template_set = Domgen::Generators::TemplateSet.new(TestTemplateSetContainer, 'foo')

    facets = [:jpa, :ee]
    target = :component
    template_key = 'someMagicKey'
    helpers = [MyHelper]
    guard = 'component.name == "SimpleModel"'
    extra_data = {'x' => 'X'}
    name = 'Foo'
    options = {:guard => guard, :name => name, :extra_data => extra_data}

    assert_generator_error('Unexpected facets: "X"') do
      Domgen::Generators::Template.new(template_set, 'X', target, template_key, helpers, options)
    end
    assert_generator_error("Unknown target 'component' for template 'someMagicKey'. Valid targets include: ") do
      Domgen::Generators::Template.new(template_set, facets, target, template_key, helpers, options)
    end

    TestTemplateSetContainer.target_manager.target(target)

    template1 = Domgen::Generators::Template.new(template_set, facets, target, template_key, helpers, options)

    assert_equal template_set, template1.template_set
    assert_equal facets, template1.facets
    assert_equal target, template1.target
    assert_equal helpers, template1.helpers
    assert_equal template_key, template1.template_key
    assert_equal guard, template1.guard
    assert_equal extra_data, template1.extra_data
    assert_equal name, template1.name
    assert_equal name, template1.to_s

    assert_generator_error('output_path unimplemented') { template1.output_path }

    render_context = template1.send(:create_context, 'SomeValue')

    assert_equal 'SomeValue', eval("component rescue 'Missing'", render_context.context_binding)
    assert_equal 'A', eval("a rescue 'Missing'", render_context.context_binding)
    assert_equal 'B', eval("b rescue 'Missing'", render_context.context_binding)
    assert_equal 'X', eval("x rescue 'Missing'", render_context.context_binding)

    assert_equal 'SimpleModel', template1.send(:name_for_element, SimpleModel.new)
    assert_equal 'Module.ComplexModel', template1.send(:name_for_element, ComplexModel.new)

    assert_equal 'Module.ComplexModel', template1.send(:name_for_element, ComplexModel.new)

    unprocessed_files1 = %w(A B C)

    template1.generate('Ignored', ComplexModel.new, unprocessed_files1)
    # ComplexModel not processed as guard protects against it
    assert_equal 3, unprocessed_files1.size

    TestTemplate.new(template_set, facets, target, template_key + '1', helpers, {}).
      generate('Ignored', SimpleModel.new, unprocessed_files1)
    assert_equal 0, unprocessed_files1.size

    assert_equal true, Domgen::Generators::Template.new(template_set, [], target, template_key + '2', helpers, {}).applicable?(SimpleModel.new)
    assert_equal true, Domgen::Generators::Template.new(template_set, facets, target, template_key + '3', helpers, {}).applicable?(SimpleModel.new)
    assert_equal false, Domgen::Generators::Template.new(template_set, facets, target, template_key + '4', helpers, {}).applicable?(SimpleModel2.new)
    assert_equal false, Domgen::Generators::Template.new(template_set, facets, target, template_key + '5', helpers, {}).applicable?(ComplexModel.new)
  end

  class StringTemplate < Domgen::Generators::SingleFileOutputTemplate
    def template_extension
      'erb'
    end

    def render_to_string(context_binding)
      'X'
    end
  end

  def test_single_file_template
    template_set = Domgen::Generators::TemplateSet.new(TestTemplateSetContainer, 'foo')

    output_filename_pattern = 'main/java/#{component.name}.java'
    template_key = 'MyFiles/templates/foo.java.erb'
    TestTemplateSetContainer.target_manager.target(:component)

    template1 = StringTemplate.new(template_set, [], :component, template_key, output_filename_pattern, [], {})

    assert_equal output_filename_pattern, template1.output_filename_pattern
    assert_equal output_filename_pattern, template1.output_path
    assert_equal template_set, template1.template_set
    assert_equal [], template1.facets
    assert_equal :component, template1.target
    assert_equal [], template1.helpers
    assert_equal template_key, template1.template_key
    assert_nil template1.guard
    assert_equal({}, template1.extra_data)
    assert_equal 'foo:foo.java', template1.name

    target_basedir = "#{temp_dir}/generated/single_file_template"
    target_filename = "#{target_basedir}/main/java/SimpleModel.java"
    other_filename = "#{target_basedir}/main/java/Other.java"
    unprocessed_files = %W(#{target_filename} #{other_filename})
    assert_equal false, File.exist?(target_filename)
    template1.generate(target_basedir, SimpleModel.new, unprocessed_files)
    assert_equal true, File.exist?(target_filename)
    assert_equal 1, unprocessed_files.size

    assert_equal 'X', IO.read(target_filename)
  end

  class DirTemplate < Domgen::Generators::SingleDirectoryOutputTemplate
    def generate_to_directory!(output_directory, element)
      FileUtils.rm_rf output_directory
      FileUtils.mkdir_p output_directory
      File.write("#{output_directory}/foo.txt",'X')
    end
  end

  def test_single_directory_template
    template_set = Domgen::Generators::TemplateSet.new(TestTemplateSetContainer, 'foo')

    output_directory_pattern = 'assets/#{component.name}'
    template_key = 'MyFiles/templates/noft'
    TestTemplateSetContainer.target_manager.target(:component)

    template1 = DirTemplate.new(template_set, [], :component, template_key, output_directory_pattern, [], {})

    assert_equal output_directory_pattern, template1.output_directory_pattern
    assert_equal output_directory_pattern, template1.output_path
    assert_equal template_set, template1.template_set
    assert_equal [], template1.facets
    assert_equal :component, template1.target
    assert_equal [], template1.helpers
    assert_equal template_key, template1.template_key
    assert_nil template1.guard
    assert_equal({}, template1.extra_data)
    assert_equal 'foo:MyFiles/templates/noft', template1.name

    target_basedir = "#{temp_dir}/generated/single_dir_template/"
    target_filename = "#{target_basedir}/assets/SimpleModel/foo.txt"
    other_filename = "#{target_basedir}/main/java/Other.java"
    unprocessed_files = %W(#{target_filename} #{other_filename})
    assert_equal false, File.exist?(target_filename)
    template1.generate(target_basedir, SimpleModel.new, unprocessed_files)
    assert_equal true, File.exist?(target_filename)
    assert_equal 1, unprocessed_files.size

    assert_equal 'X', IO.read(target_filename)
  end
end
