require File.expand_path('../../helper', __FILE__)

class Domgen::Facets::TestFacetContainer < Domgen::TestCase
  class Component < Domgen.base_element(:name => true)
  end

  class Component2 < Domgen.base_element(:name => true)
  end

  module MyExtensionModule
  end

  def test_basic_operation

    assert_equal false, TestFacetContainer.facet_by_name?(:gwt)
    assert_equal false, TestFacetContainer.facet?(:gwt)
    assert_equal false, TestFacetContainer.facet_by_name?(:gwt_rpc)
    assert_equal false, TestFacetContainer.facet?(:gwt_rpc)
    assert_equal [], TestFacetContainer.facet_keys
    assert_equal 0, TestFacetContainer.facets.size

    assert_facet_error("Unknown facet 'gwt'") { TestFacetContainer.facet_by_name(:gwt) }
    assert_facet_error("Unknown facet 'gwt_rpc'") { TestFacetContainer.facet_by_name(:gwt_rpc) }

    # Make sure we can add targets
    TestFacetContainer.target_manager.target(Component, :component)

    TestFacetContainer.facet(:gwt)

    # targets should be locked after first facet defined
    assert_facet_error('Attempting to define target component when targets have been locked.') do
      TestFacetContainer.target_manager.target(Component, :component)
    end

    assert_equal true, TestFacetContainer.facet_by_name?(:gwt)
    assert_equal true, TestFacetContainer.facet?(:gwt)
    assert_equal false, TestFacetContainer.facet_by_name?(:gwt_rpc)
    assert_equal false, TestFacetContainer.facet?(:gwt_rpc)
    assert_equal %w(gwt), TestFacetContainer.facet_keys
    assert_equal 1, TestFacetContainer.facets.size

    assert_facet_error("Unknown facet 'gwt_rpc'") { TestFacetContainer.facet_by_name(:gwt_rpc) }

    assert_equal TestFacetContainer, TestFacetContainer.facet_by_name(:gwt).facet_container
    assert_equal :gwt, TestFacetContainer.facet_by_name(:gwt).key
    assert_equal [], TestFacetContainer.facet_by_name(:gwt).required_facets
    assert_equal [], TestFacetContainer.facet_by_name(:gwt).suggested_facets

    TestFacetContainer.facet(:gwt_rpc => [:gwt])

    assert_equal true, TestFacetContainer.facet_by_name?(:gwt)
    assert_equal true, TestFacetContainer.facet?(:gwt)
    assert_equal true, TestFacetContainer.facet_by_name?(:gwt_rpc)
    assert_equal true, TestFacetContainer.facet?(:gwt_rpc)
    assert_equal %w(gwt gwt_rpc), TestFacetContainer.facet_keys
    assert_equal 2, TestFacetContainer.facets.size

    assert_equal TestFacetContainer, TestFacetContainer.facet_by_name(:gwt_rpc).facet_container
    assert_equal :gwt_rpc, TestFacetContainer.facet_by_name(:gwt_rpc).key
    assert_equal [:gwt], TestFacetContainer.facet_by_name(:gwt_rpc).required_facets
    assert_equal [], TestFacetContainer.facet_by_name(:gwt_rpc).suggested_facets

    assert_facet_error('Attempting to redefine facet gwt') { TestFacetContainer.facet(:gwt) }

    assert_facet_error("Unknown definition form '{:x=>:y, :z=>1}'") { TestFacetContainer.facet(:x => :y, :z => 1) }
  end

  def test_dependent_facets
    TestFacetContainer.facet(:gwt)
    TestFacetContainer.facet(:gwt_rpc => [:gwt])
    TestFacetContainer.facet(:imit => [:gwt_rpc, :jpa])
    TestFacetContainer.facet(:ee)
    TestFacetContainer.facet(:jpa => [:ee])

    assert_equal [:gwt], TestFacetContainer.dependent_facets(:gwt)
    assert_equal [:imit, :jpa, :ee, :gwt_rpc, :gwt].sort, TestFacetContainer.dependent_facets(:imit).sort
    assert_equal [:jpa, :ee].sort, TestFacetContainer.dependent_facets(:jpa).sort
  end
end
