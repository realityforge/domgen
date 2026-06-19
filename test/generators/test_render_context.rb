require File.expand_path('../../helper', __FILE__)

class Domgen::Generators::TestRenderContext < Domgen::TestCase

  module MyHelper
    def gen_x
      'X'
    end

    def gen_y
      'Y'
    end
  end

  def test_basic_operation
    render_context = Domgen::Generators::RenderContext.new

    assert_equal 'Missing', eval("gen_x rescue 'Missing'", render_context.context_binding)
    assert_equal 'Missing', eval("gen_y rescue 'Missing'", render_context.context_binding)
    assert_equal 'Missing', eval("a rescue 'Missing'", render_context.context_binding)
    assert_equal 'Missing', eval("b rescue 'Missing'", render_context.context_binding)

    render_context.add_helper(MyHelper)

    assert_equal 'X', eval("gen_x rescue 'Missing'", render_context.context_binding)
    assert_equal 'Y', eval("gen_y rescue 'Missing'", render_context.context_binding)
    assert_equal 'Missing', eval("a rescue 'Missing'", render_context.context_binding)
    assert_equal 'Missing', eval("b rescue 'Missing'", render_context.context_binding)

    render_context.set_local_variable(:a, 'A')

    assert_equal 'X', eval("gen_x rescue 'Missing'", render_context.context_binding)
    assert_equal 'Y', eval("gen_y rescue 'Missing'", render_context.context_binding)
    assert_equal 'A', eval("a rescue 'Missing'", render_context.context_binding)
    assert_equal 'Missing', eval("b rescue 'Missing'", render_context.context_binding)

    render_context.set_local_variable(:b, 'B')

    assert_equal 'X', eval("gen_x rescue 'Missing'", render_context.context_binding)
    assert_equal 'Y', eval("gen_y rescue 'Missing'", render_context.context_binding)
    assert_equal 'A', eval("a rescue 'Missing'", render_context.context_binding)
    assert_equal 'B', eval("b rescue 'Missing'", render_context.context_binding)
  end
end
