require File.expand_path('../../helper', __FILE__)

class Domgen::Generators::TestTargetManager < Domgen::TestCase

  def test_target
    target_manager = Domgen::Generators::TargetManager.new(TestTemplateSetContainer)
    target1 = Domgen::Generators::Target.new(target_manager, :repository, nil, {})

    assert_equal :repository, target1.qualified_key
    assert_equal :repository, target1.key
    assert_nil target1.container_key
    assert_equal 'repositories', target1.access_method
    assert_nil target1.facet_key
    assert_equal true, target1.standard?

    target2 = Domgen::Generators::Target.new(target_manager, :data_module, :repository, {})

    assert_equal :data_module, target2.qualified_key
    assert_equal :data_module, target2.key
    assert_equal :repository, target2.container_key
    assert_equal 'data_modules', target2.access_method
    assert_nil target2.facet_key
    assert_equal true, target2.standard?

    target3 = Domgen::Generators::Target.new(target_manager, :entrypoint, :repository, :facet_key => :gwt)

    assert_equal :'gwt.entrypoint', target3.qualified_key
    assert_equal :entrypoint, target3.key
    assert_equal :repository, target3.container_key
    assert_equal 'entrypoints', target3.access_method
    assert_equal :gwt, target3.facet_key
    assert_equal false, target3.standard?

    target4 = Domgen::Generators::Target.new(target_manager, :persistence_unit, :repository, :facet_key => :jpa, :access_method => 'standard_persistence_units')

    assert_equal :'jpa.persistence_unit', target4.qualified_key
    assert_equal :persistence_unit, target4.key
    assert_equal :repository, target4.container_key
    assert_equal 'standard_persistence_units', target4.access_method
    assert_equal :jpa, target4.facet_key
    assert_equal false, target4.standard?

    target1 = Domgen::Generators::Target.new(target_manager, :project, nil, :access_method => 'project_set')

    assert_equal :project, target1.qualified_key
    assert_equal :project, target1.key
    assert_nil target1.container_key
    assert_equal 'project_set', target1.access_method
    assert_nil target1.facet_key
    assert_equal true, target1.standard?

    assert_generator_error('Attempting to redefine target project') { Domgen::Generators::Target.new(target_manager, :project, nil, {}) }

    assert_generator_error("Target 'foo' defines container as 'bar' but no such target exists.") { Domgen::Generators::Target.new(target_manager, :foo, :bar, {}) }
  end

  def test_target_manager_basic_operation

    target_manager = Domgen::Generators::TargetManager.new(TestTemplateSetContainer)

    assert_equal false, target_manager.is_target_valid?(:project)
    assert_equal [], target_manager.target_keys
    assert_equal false, target_manager.target_by_key?(:project)

    target_manager.target(:project)

    assert_equal true, target_manager.is_target_valid?(:project)
    assert_equal [:project], target_manager.target_keys
    assert_equal true, target_manager.target_by_key?(:project)
    assert_equal 1, target_manager.targets.size
    assert_equal :project, target_manager.targets[0].key

    target_manager.target(:component, :project, :facet_key => :jsc, :access_method => 'comps')

    assert_equal true, target_manager.is_target_valid?(:'jsc.component')
    assert_equal true, target_manager.target_by_key?(:'jsc.component')
    assert_equal 2, target_manager.targets.size
    target = target_manager.target_by_key(:'jsc.component')
    assert_equal :component, target.key
    assert_equal :project, target.container_key
    assert_equal :jsc, target.facet_key
    assert_equal 'comps', target.access_method

    assert_equal 1, target_manager.targets_by_container(:project).size
    assert_equal :component, target_manager.targets_by_container(:project)[0].key

    assert_generator_error("Can not find target with key 'foo'") { target_manager.target_by_key(:foo) }
  end
end
