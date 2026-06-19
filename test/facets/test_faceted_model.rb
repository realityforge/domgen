require File.expand_path('../../helper', __FILE__)

class Domgen::Facets::TestFacetedModel < Domgen::TestCase
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
  end

  def test_activation
    TestFacetContainer.target_manager.target(Repository, :repository)
    TestFacetContainer.target_manager.target(Entity, :entity, :repository)
    TestFacetContainer.target_manager.target(Attribute, :attribute, :entity)

    TestFacetContainer.facet(:json)
    TestFacetContainer.facet(:jpa)
    TestFacetContainer.facet(:gwt)
    TestFacetContainer.facet(:gwt_rpc => [:gwt])
    TestFacetContainer.facet(:imit => [:gwt_rpc]) do |f|
      f.suggested_facets << :jpa
    end

    assert_equal 5, TestFacetContainer.facets.size

    repository = Repository.new(:MyRepo) do |r|
      TestFacetContainer.target_manager.apply_extension(r)

      r.enable_facet(:json)

      r.entity(:MyEntityA) do |e|
        TestFacetContainer.target_manager.apply_extension(e)
        e.attribute(:MyAttr1) do |a|
          TestFacetContainer.target_manager.apply_extension(a)
        end
        e.disable_facet(:json)
        e.attribute(:MyAttr2) do |a|
          TestFacetContainer.target_manager.apply_extension(a)
        end
      end

      r.entity(:MyEntityB) do |e|
        TestFacetContainer.target_manager.apply_extension(e)
      end
    end

    entity1 = repository.entities[0]
    attribute1 = entity1.attributes[0]
    attribute2 = entity1.attributes[1]
    entity2 = repository.entities[1]

    assert_equal [:json], repository.enabled_facets
    assert_equal [], entity1.enabled_facets
    assert_equal [:json], entity2.enabled_facets
    assert_equal [], attribute1.enabled_facets
    assert_equal [], attribute2.enabled_facets

    repository.enable_facet(:imit)
    assert_facet_error('Facet imit already enabled.') { repository.enable_facet(:imit) }

    assert_equal [:json, :gwt, :gwt_rpc, :jpa, :imit], repository.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit], entity1.enabled_facets
    assert_equal [:json, :gwt, :gwt_rpc, :jpa, :imit], entity2.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit], attribute1.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit], attribute2.enabled_facets

    entity1.disable_facet(:gwt)

    assert_equal [:json, :gwt, :gwt_rpc, :jpa, :imit], repository.enabled_facets
    assert_equal [:jpa], entity1.enabled_facets
    assert_equal [:json, :gwt, :gwt_rpc, :jpa, :imit], entity2.enabled_facets
    assert_equal [:jpa], attribute1.enabled_facets
    assert_equal [:jpa], attribute2.enabled_facets

    entity1.enable_facet(:json)

    assert_equal [:json, :gwt, :gwt_rpc, :jpa, :imit], repository.enabled_facets
    assert_equal [:jpa, :json], entity1.enabled_facets
    assert_equal [:json, :gwt, :gwt_rpc, :jpa, :imit], entity2.enabled_facets
    assert_equal [:jpa, :json], attribute1.enabled_facets
    assert_equal [:jpa, :json], attribute2.enabled_facets

    repository.disable_facet(:json)

    assert_equal [:gwt, :gwt_rpc, :jpa, :imit], repository.enabled_facets
    assert_equal [:jpa], entity1.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit], entity2.enabled_facets
    assert_equal [:jpa], attribute1.enabled_facets
    assert_equal [:jpa], attribute2.enabled_facets

    repository.enable_facets([:json])

    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], repository.enabled_facets
    assert_equal [:jpa, :json], entity1.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], entity2.enabled_facets
    assert_equal [:jpa, :json], attribute1.enabled_facets
    assert_equal [:jpa, :json], attribute2.enabled_facets

    # No-op as all enabled
    repository.enable_facets([:json])

    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], repository.enabled_facets
    assert_equal [:jpa, :json], entity1.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], entity2.enabled_facets
    assert_equal [:jpa, :json], attribute1.enabled_facets
    assert_equal [:jpa, :json], attribute2.enabled_facets

    assert_facet_error('Facet json already enabled.') { repository.enable_facets!([:json]) }

    # Try using brackets
    repository.disable_facets([:json, :imit])
    repository.enable_facets([:imit, :json])

    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], repository.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], entity1.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], entity2.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], attribute1.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], attribute2.enabled_facets

    # Try using raw facet list
    repository.disable_facets(:json, :imit)
    repository.enable_facets(:imit, :json)

    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], repository.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], entity1.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], entity2.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], attribute1.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], attribute2.enabled_facets

    # Try forcing
    repository.disable_facets(:json, :imit)
    repository.enable_facets!(:imit, :json)

    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], repository.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], entity1.enabled_facets
    assert_equal [:gwt, :gwt_rpc, :jpa, :imit, :json], entity2.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], attribute1.enabled_facets
    assert_equal [:jpa, :gwt, :gwt_rpc, :imit, :json], attribute2.enabled_facets

    attribute2.disable_facets_not_in(:json)

    assert_equal [:json], attribute2.enabled_facets

    attribute1.disable_facets_not_in([:imit])

    assert_equal [:gwt, :gwt_rpc, :imit], attribute1.enabled_facets

    entity2.disable_facets_not_in([:gwt_rpc, :jpa])

    assert_equal [:gwt, :gwt_rpc, :jpa], entity2.enabled_facets
  end

  def test_extension_point
    TestFacetContainer.target_manager.target(Repository, :repository)
    TestFacetContainer.target_manager.target(Entity, :entity, :repository)
    TestFacetContainer.target_manager.target(Attribute, :attribute, :entity)

    TestFacetContainer.facet(:json) do |f|
      f.enhance(Entity) do
        def hook2?
          @hook2 ||= false
        end

        def hook2
          @hook2 = true
        end
      end
    end

    TestFacetContainer.facet(:jpa) do |f|
      f.enhance(Repository) do
        def hook1?
          @hook1 ||= false
        end

        def hook1
          @hook1 = true
        end

        def hook2?
          @hook2 ||= false
        end

        def hook2
          @hook2 = true
        end
      end

      f.enhance(Attribute) do
        def hook2?
          @hook2 ||= false
        end

        def hook2
          @hook2 = true
        end
      end
    end

    repository = Repository.new(:MyRepo) do |r|
      TestFacetContainer.target_manager.apply_extension(r)

      r.enable_facets(:json, :jpa)

      r.entity(:MyEntityA) do |e|
        TestFacetContainer.target_manager.apply_extension(e)
        e.disable_facet(:json)
        e.attribute(:MyAttr1) do |a|
          TestFacetContainer.target_manager.apply_extension(a)
        end
        e.attribute(:MyAttr2) do |a|
          TestFacetContainer.target_manager.apply_extension(a)
        end
      end

      r.entity(:MyEntityB) do |e|
        TestFacetContainer.target_manager.apply_extension(e)
      end
    end

    entity1 = repository.entities[0]
    entity2 = repository.entities[1]
    attribute1 = entity1.attributes[0]
    attribute2 = entity1.attributes[1]

    assert_equal false, repository.jpa.hook1?
    assert_equal false, repository.jpa.hook2?
    assert_equal false, entity2.json.hook2?
    assert_equal false, attribute1.jpa.hook2?
    assert_equal false, attribute2.jpa.hook2?

    repository.send(:extension_point, :hook1)

    assert_equal true, repository.jpa.hook1?
    assert_equal false, repository.jpa.hook2?
    assert_equal false, entity2.json.hook2?
    assert_equal false, attribute1.jpa.hook2?
    assert_equal false, attribute2.jpa.hook2?

    repository.send(:extension_point, :hook2)

    assert_equal true, repository.jpa.hook1?
    assert_equal true, repository.jpa.hook2?
    assert_equal true, entity2.json.hook2?
    assert_equal true, attribute1.jpa.hook2?
    assert_equal true, attribute2.jpa.hook2?
  end

  def test_facet_container_locking
    TestFacetContainer.target_manager.target(Repository, :repository)

    TestFacetContainer.facet(:json)

    assert_equal 1, TestFacetContainer.facets.size

    Repository.new(:MyRepo) do |r|
      TestFacetContainer.target_manager.apply_extension(r)
    end

    assert_facet_error('Attempting to define facet gwt after facet manager is locked') { TestFacetContainer.facet(:gwt) }
  end
end
