require File.expand_path('../../helper', __FILE__)

class Domgen::TestBaseElement < Domgen::TestCase

  class TestElement < Domgen::BaseElement
    attr_accessor :a
    attr_accessor :b
    attr_accessor :c

    def to_s
      'TestElement'
    end
  end

  def test_basic_operation
    element1 = TestElement.new do |e|
      e.a = 1
      e.b = 2
      e.c = 3
    end
    assert_equal 1, element1.a
    assert_equal 2, element1.b
    assert_equal 3, element1.c

    element2 = TestElement.new(:a => '1', :b => '2', 'c' => '3') do |e|
      e.a = 1
    end
    assert_equal 1, element2.a
    assert_equal '2', element2.b
    assert_equal '3', element2.c

    assert_raise_message("Attempted to configure property \"x\" on Domgen::TestBaseElement::TestElement but property does not exist.") do
      TestElement.new(:x => '1')
    end
  end

  class TestElementA < Domgen.base_element
  end

  class TestElementB < Domgen.base_element(:container_key => 'container')
  end

  class TestElementC < Domgen.base_element(:name => true)
  end

  class TestElementD < Domgen.base_element(:key => true)
  end

  class TestElementE < Domgen.base_element(:name => true, :key => true)
  end

  class TestElementF < Domgen.base_element(:container_key => 'container', :name => true, :key => true)
  end

  class TestElementG < Domgen.base_element(:pre_config_code => 'self.foo = 1')
    attr_accessor :foo
  end

  def test_base_element_constructor
    begin
      e = TestElementA.new
      assert_raise(NoMethodError) { e.key }
      assert_raise(NoMethodError) { e.name }
    end

    begin
      e = TestElementB.new('FakeContainer')
      assert_raise(NoMethodError) { e.key }
      assert_raise(NoMethodError) { e.name }
      assert_equal e.container, 'FakeContainer'
    end

    begin
      e = TestElementC.new('myName')
      assert_raise(NoMethodError) { e.key }
      assert_equal e.name, 'myName'
    end

    begin
      e = TestElementD.new('myKey')
      assert_raise(NoMethodError) { e.name }
      assert_equal e.key, 'myKey'
    end

    begin
      e = TestElementE.new('myKey', 'myName')
      assert_equal e.key, 'myKey'
      assert_equal e.name, 'myName'
    end

    begin
      e = TestElementF.new('FakeContainer', 'myKey', 'myName')
      assert_equal e.container, 'FakeContainer'
      assert_equal e.key, 'myKey'
      assert_equal e.name, 'myName'
    end

    begin
      TestElementG.new do |te|
        assert_equal te.foo, 1
      end
    end
  end
end
