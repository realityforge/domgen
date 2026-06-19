require File.expand_path('../../helper', __FILE__)

class Domgen::Facets::TestTargetManager < Domgen::TestCase

  class Unused < Domgen.base_element(:name => true)
  end

  class DataModule < Domgen.base_element(:name => true, :container_key => :repository)
  end

  class Repository < Domgen.base_element(:name => true)
    def data_module(name, options = {}, &block)
      data_module_map[name.to_s] = DataModule.new(self, name, options, &block)
    end

    def data_modules
      data_module_map.values
    end

    def data_module_map
      @data_module_map ||= {}
    end
  end

  class Fragment < Domgen.base_element(:name => true, :container_key => :component)
  end

  class Component < Domgen.base_element(:name => true, :container_key => :project)
    def fragment(name, options = {}, &block)
      fragment_map[name.to_s] = Component.new(self, name, options, &block)
    end

    def fragments
      fragment_map.values
    end

    def fragment_map
      @fragment_map ||= {}
    end
  end

  class Project < Domgen.base_element(:name => true)
    def component(name, options = {}, &block)
      component_map[name.to_s] = Component.new(self, name, options, &block)
    end

    def components
      component_map.values
    end

    def component_map
      @component_map ||= {}
    end
  end

  def test_target
    target_manager = Domgen::Facets::TargetManager.new(TestFacetContainer)
    target1 = Domgen::Facets::Target.new(target_manager, Repository, :repository, nil, {})

    assert_equal target_manager, target1.target_manager
    assert_equal Repository, target1.model_class
    assert_equal :repository, target1.key
    assert_nil target1.container_key
    assert_equal :repositories, target1.access_method
    assert_equal :repository, target1.inverse_access_method
    assert_equal 'Domgen::TestCase::TestFacetContainer::FacetDefinitions::RepositoryExtension', target1.extension_module.name

    target2 = Domgen::Facets::Target.new(target_manager, DataModule, :data_module, :repository, {})

    assert_equal target_manager, target2.target_manager
    assert_equal DataModule, target2.model_class
    assert_equal :data_module, target2.key
    assert_equal :repository, target2.container_key
    assert_equal :data_modules, target2.access_method
    assert_equal :data_module, target2.inverse_access_method
    assert_equal 'Domgen::TestCase::TestFacetContainer::FacetDefinitions::DataModuleExtension', target2.extension_module.name

    target1 = Domgen::Facets::Target.new(target_manager, Project, :project, nil, :access_method => :project_set, :inverse_access_method => 'prj')

    assert_equal target_manager, target1.target_manager
    assert_equal Project, target1.model_class
    assert_equal :project, target1.key
    assert_nil target1.container_key
    assert_equal :project_set, target1.access_method
    assert_equal :prj, target1.inverse_access_method
    assert_equal 'Domgen::TestCase::TestFacetContainer::FacetDefinitions::ProjectExtension', target1.extension_module.name

    assert_facet_error('Attempting to redefine target project') { Domgen::Facets::Target.new(target_manager, Project, :project, nil, {}) }

    assert_facet_error("Target 'foo' defines container as 'bar' but no such target exists.") { Domgen::Facets::Target.new(target_manager, Unused, :foo, :bar, {}) }
  end

  def test_target_manager_basic_operation

    target_manager = Domgen::Facets::TargetManager.new(TestFacetContainer)

    assert_equal false, target_manager.is_target_valid?(:project)
    assert_equal [], target_manager.target_keys
    assert_equal false, target_manager.target_by_key?(:project)

    assert_facet_error("Can not find target with model class 'Domgen::Facets::TestTargetManager::Project'") { target_manager.target_by_model_class(Project) }

    target_manager.target(Project, :project)

    assert_equal true, target_manager.is_target_valid?(:project)
    assert_equal [:project], target_manager.target_keys
    assert_equal true, target_manager.target_by_key?(:project)
    assert_equal 1, target_manager.targets.size
    assert_equal :project, target_manager.targets[0].key
    # noinspection RubyArgCount
    assert_equal :project, target_manager.target_by_model_class(Project).key

    target_manager.target(Component, :component, :project, :access_method => :comps)

    assert_equal true, target_manager.is_target_valid?(:component)
    assert_equal true, target_manager.target_by_key?(:component)
    assert_equal 2, target_manager.targets.size
    target = target_manager.target_by_key(:component)
    assert_equal :component, target.key
    assert_equal :project, target.container_key
    assert_equal :comps, target.access_method

    assert_equal 1, target_manager.targets_by_container(:project).size
    assert_equal :component, target_manager.targets_by_container(:project)[0].key

    assert_facet_error("Can not find target with key 'foo'") { target_manager.target_by_key(:foo) }
  end

  def test_apply_extension
    TestFacetContainer.target_manager.target(Project, :project)
    TestFacetContainer.target_manager.target(Component, :component, :project)
    TestFacetContainer.target_manager.target(Fragment, :fragment, :component)

    TestFacetContainer.facet(:json)
    TestFacetContainer.facet(:jpa)
    TestFacetContainer.facet(:gwt) do |f|
      f.enhance(Project) do
        def name
          "Gwt#{project.name}"
        end
      end
    end

    project = Project.new(:MyProject) do |p|
      p.component(:MyComponent1) do |c|
        c.fragment(:MyFragment)
      end
    end

    component1 = project.components[0]
    fragment1 = component1.fragments[0]

    assert_equal false, project.respond_to?(:facet_enabled?)
    assert_equal false, component1.respond_to?(:facet_enabled?)
    assert_equal false, fragment1.respond_to?(:facet_enabled?)

    assert_equal false, project.respond_to?(:parent)
    assert_equal false, component1.respond_to?(:parent)
    assert_equal false, fragment1.respond_to?(:parent)

    TestFacetContainer.target_manager.apply_extension(project)
    TestFacetContainer.target_manager.apply_extension(component1)
    TestFacetContainer.target_manager.apply_extension(fragment1)

    assert_equal true, project.respond_to?(:facet_enabled?)
    assert_equal true, component1.respond_to?(:facet_enabled?)
    assert_equal true, fragment1.respond_to?(:facet_enabled?)

    assert_equal false, project.respond_to?(:parent)
    assert_equal true, component1.respond_to?(:parent)
    assert_equal true, fragment1.respond_to?(:parent)

    assert_equal project, component1.parent
    assert_equal component1, fragment1.parent

    project.enable_facets(:json, :gwt)

    assert_equal [:json, :gwt], project.enabled_facets

    assert_equal true, project.respond_to?(:facet_enabled?)
    assert_equal true, component1.respond_to?(:facet_enabled?)
    assert_equal true, fragment1.respond_to?(:facet_enabled?)

    assert_equal [:json, :gwt], component1.enabled_facets

    component1.disable_facet(:gwt)

    assert_equal [:json], component1.enabled_facets

    assert_equal true, project.respond_to?(:facet_enabled?)
    assert_equal true, component1.respond_to?(:facet_enabled?)
    assert_equal true, fragment1.respond_to?(:facet_enabled?)

    assert_equal [:json], fragment1.enabled_facets
  end

  class Project2 < Domgen.base_element(:name => true)
  end

  def test_apply_extension_with_multiple_enhances
    TestFacetContainer.target_manager.target(Project2, :project)

    TestFacetContainer.facet(:gwt) do |f|
      f.enhance(Project2) do
        def name
          "Gwt#{project.name}"
        end
      end
      f.enhance(Project2) do
        def name2
          "Gwt2#{project.name}"
        end
      end
    end

    project = Project2.new(:MyProject)
    assert_equal false, project.respond_to?(:facet_enabled?)
    assert_equal false, project.respond_to?(:parent)

    TestFacetContainer.target_manager.apply_extension(project)

    assert_equal true, project.respond_to?(:facet_enabled?)
    project.enable_facets(:gwt)

    assert_equal 'GwtMyProject', project.gwt.name
    assert_equal 'Gwt2MyProject', project.gwt.name2
  end
end
