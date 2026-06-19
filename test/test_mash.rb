require File.expand_path('helper', __dir__)

class Domgen::TestMash < Domgen::TestCase
  def test_mash
    m = Domgen::Mash.new
    assert_equal m.keys.size, 0
    assert m['hello'].is_a?(Domgen::Mash)
    assert_equal m.keys.size, 1
    m['hello']['bar'] = 1
    assert_equal m.keys.size, 1
    assert_equal m['hello'].keys.size, 1
    assert_equal m['hello']['bar'], 1
  end

  def test_from
    m = Domgen::Mash.from('a' => {'b' => 1}, 'c' => true)
    assert_equal m.keys.size, 2
    assert m['a'].is_a?(Domgen::Mash)
    assert_equal m['a'].keys.size, 1
    assert_equal m['a']['b'], 1
    assert_equal m['c'], true
  end

  def test_to_h
    m = Domgen::Mash.new
    m['a'] = 1
    m['b'] = 's'
    m['c'] = true
    m['d'] = false
    m['e'] = 4.3
    m['f']['a'] = 1
    m['f']['b'] = 's'
    m['f']['c'] = true
    m['f']['d'] = false
    m['f']['e'] = 4.3
    m['f']['f']['a'] = 1
    m['f']['f']['b'] = 's'
    m['f']['f']['c'] = true
    m['f']['f']['d'] = false
    m['f']['f']['e'] = 4.3
    m['g'] = nil
    h = m.to_h
    assert_nil h['g']
    assert_equal h['a'], 1
    assert_equal h['b'], 's'
    assert_equal h['c'], true
    assert_equal h['d'], false
    assert_equal h['e'], 4.3
    assert_equal h['f']['a'], 1
    assert_equal h['f']['b'], 's'
    assert_equal h['f']['c'], true
    assert_equal h['f']['d'], false
    assert_equal h['f']['e'], 4.3
    assert_equal h['f']['f']['a'], 1
    assert_equal h['f']['f']['b'], 's'
    assert_equal h['f']['f']['c'], true
    assert_equal h['f']['f']['d'], false
    assert_equal h['f']['f']['e'], 4.3
    assert_nil h['g']
  end

  def test_merge
    m = Domgen::Mash.new
    m['a'] = 1
    m['b'] = 's'
    m['c'] = true
    m['d'] = false
    m['e'] = 4.3
    m['f']['a'] = 1
    m['f']['b']['p'] = 1
    m['g'] = [1]

    m2 = Domgen::Mash.new
    m2['e'] = 4.2
    m2['f']['c'] = 1
    m2['f']['b']['q'] = 1
    m2['g'] = [3, 4]

    result = m.merge(m2)

    h = m.to_h
    assert_equal h['g'], [1]
    assert_equal h['a'], 1
    assert_equal h['b'], 's'
    assert_equal h['c'], true
    assert_equal h['d'], false
    assert_equal h['e'], 4.3
    assert_equal h['f']['a'], 1
    assert_equal h['f']['b']['p'], 1

    h = m2.to_h
    assert_equal h['e'], 4.2
    assert_equal h['f']['c'], 1
    assert_equal h['f']['b']['q'], 1
    assert_equal h['g'], [3, 4]

    h = result.to_h
    assert_equal h['g'], [1, 3, 4]
    assert_equal h['a'], 1
    assert_equal h['b'], 's'
    assert_equal h['c'], true
    assert_equal h['d'], false
    assert_equal h['e'], 4.2
    assert_equal h['f']['a'], 1
    assert_equal h['f']['b']['p'], 1
    assert_equal h['f']['b']['q'], 1
    assert_equal h['f']['c'], 1
  end

  def test_sort
    m = Domgen::Mash.new
    m['3'] = 1
    m['2'] = 's'
    m['1'] = true
    m['0'] = false
    m['a'] = 4.3
    m['c']['a'] = 1
    m['c']['b']['p'] = 2
    m['c']['b']['a'] = 3
    m['d'] = [1]

    m2 = m.sort

    h = m.to_h
    assert_equal h['3'], 1
    assert_equal h['2'], 's'
    assert_equal h['1'], true
    assert_equal h['0'], false
    assert_equal h['a'], 4.3
    assert_equal h['c']['a'], 1
    assert_equal h['c']['b']['p'], 2
    assert_equal h['c']['b']['a'], 3
    assert_equal h['d'], [1]

    assert_equal h.keys, %w(3 2 1 0 a c d)

    h = m2.to_h
    assert_equal h['3'], 1
    assert_equal h['2'], 's'
    assert_equal h['1'], true
    assert_equal h['0'], false
    assert_equal h['a'], 4.3
    assert_equal h['c']['a'], 1
    assert_equal h['c']['b']['p'], 2
    assert_equal h['c']['b']['a'], 3
    assert_equal h['d'], [1]

    assert_equal h.keys, %w(0 1 2 3 a c d)
  end
end
