require File.expand_path('helper', __dir__)

class Domgen::TestNaming < Domgen::Naming::TestCase
  def test_pluralize
    assert_equal 'cats', Domgen::Naming.pluralize('cat')
    assert_equal 'cats', Domgen::Naming.pluralize(:cat)
    assert_equal 'poppies', Domgen::Naming.pluralize('poppy')
    assert_equal 'says', Domgen::Naming.pluralize('say')
    assert_equal 'fooes', Domgen::Naming.pluralize('foo')
    assert_equal 'dispatches', Domgen::Naming.pluralize('dispatch')
    assert_equal 'bushes', Domgen::Naming.pluralize('bush')
    assert_equal 'losses', Domgen::Naming.pluralize('loss')
    assert_equal 'boxes', Domgen::Naming.pluralize('box')
    assert_equal 'blitzes', Domgen::Naming.pluralize('blitz')
    assert_equal 'trusses', Domgen::Naming.pluralize('truss')
    assert_equal 'buses', Domgen::Naming.pluralize('bus')
    assert_equal 'marshes', Domgen::Naming.pluralize('marsh')
    assert_equal 'potatoes', Domgen::Naming.pluralize('potato')
    assert_equal 'tomatoes', Domgen::Naming.pluralize('tomato')
    assert_equal 'analyses', Domgen::Naming.pluralize('analysis')
    assert_equal 'ellipses', Domgen::Naming.pluralize('ellipsis')
    assert_equal 'phenomena', Domgen::Naming.pluralize('phenomenon')
    assert_equal 'criteria', Domgen::Naming.pluralize('criterion')
  end

  def test_custom_pluralization_rules
    assert_equal 'cats', Domgen::Naming.pluralize('cat')
    Domgen::Naming.add_pluralization_rule do |string|
      string == 'cat' ? 'catz' : nil
    end
    assert_equal 'catz', Domgen::Naming.pluralize('cat')
    Domgen::Naming.clear_pluralization_rules
    assert_equal 'cats', Domgen::Naming.pluralize('cat')
  end

  def test_custom_pluralization_rules_ordering
    assert_equal 'cats', Domgen::Naming.pluralize('cat')
    Domgen::Naming.add_pluralization_rule do |string|
      string == 'cat' ? 'catz' : nil
    end
    assert_equal 'catz', Domgen::Naming.pluralize('cat')
    Domgen::Naming.add_pluralization_rule do |string|
      string == 'cat' ? 'cattles' : nil
    end
    assert_equal 'cattles', Domgen::Naming.pluralize('cat')
  end

  def test_custom_pluralization_overlap_with_defaults
    assert_equal 'IsAsGoodAses', Domgen::Naming.pluralize('IsAsGoodAs')
    Domgen::Naming.add_pluralization_rule do |string|
      string.to_s == 'IsAsGoodAs' ? 'IsAsGoodAsSet' : nil
    end
    assert_equal 'IsAsGoodAsSet', Domgen::Naming.pluralize('IsAsGoodAs')
  end

  def test_default_pluralization_rules
    assert_equal 'children', Domgen::Naming.pluralize('child')
    assert_equal 'Children', Domgen::Naming.pluralize('Child')
    Domgen::Naming.clear_pluralization_rules
    assert_equal 'childs', Domgen::Naming.pluralize('child')
    assert_equal 'Childs', Domgen::Naming.pluralize('Child')
    Domgen::Naming.reset
    assert_equal 'children', Domgen::Naming.pluralize('child')
    assert_equal 'Children', Domgen::Naming.pluralize('Child')
  end

  def test_basics
    assert_equal Domgen::Naming.camelize('thisIsCamelCased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.camelize('ThisIsCamelCased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.camelize('this_Is_Camel_Cased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.camelize('this_Is_camel_cased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.camelize('EJB'), 'ejb'
    assert_equal Domgen::Naming.camelize('EJBContainer'), 'ejbContainer'
    assert_equal Domgen::Naming.camelize('_someField'), 'someField'

    assert_equal Domgen::Naming.camelize?('_someField'), false
    assert_equal Domgen::Naming.camelize?('someField'), true
    assert_equal Domgen::Naming.camelize?(:someField), true

    assert_equal Domgen::Naming.pascal_case('thisIsCamelCased'), 'ThisIsCamelCased'
    assert_equal Domgen::Naming.pascal_case('ThisIsCamelCased'), 'ThisIsCamelCased'
    assert_equal Domgen::Naming.pascal_case('this_Is_Camel_Cased'), 'ThisIsCamelCased'
    assert_equal Domgen::Naming.pascal_case('this_Is_camel_cased'), 'ThisIsCamelCased'
    assert_equal Domgen::Naming.pascal_case('EJB'), 'EJB'
    assert_equal Domgen::Naming.pascal_case('EJBContainer'), 'EJBContainer'
    assert_equal Domgen::Naming.pascal_case('_someField'), 'SomeField'

    assert_equal Domgen::Naming.pascal_case?('FindByID'), true
    assert_equal Domgen::Naming.pascal_case?('findByID'), false
    assert_equal Domgen::Naming.pascal_case?(:FindByID), true

    assert_equal Domgen::Naming.humanize('thisIsCamelCased'), 'This Is Camel Cased'
    assert_equal Domgen::Naming.humanize('ThisIsCamelCased'), 'This Is Camel Cased'
    assert_equal Domgen::Naming.humanize('this_Is_Camel_Cased'), 'This Is Camel Cased'
    assert_equal Domgen::Naming.humanize('this_Is_camel_cased'), 'This Is Camel Cased'
    assert_equal Domgen::Naming.humanize('EJB'), 'EJB'
    assert_equal Domgen::Naming.humanize('EJBContainer'), 'EJB Container'
    assert_equal Domgen::Naming.humanize('_someField'), 'Some Field'

    assert_equal Domgen::Naming.humanize?('Find By ID'), true
    assert_equal Domgen::Naming.humanize?('find By ID'), false
    assert_equal Domgen::Naming.humanize?(:'Find By ID'), true

    assert_equal Domgen::Naming.underscore('thisIsCamelCased'), 'this_is_camel_cased'
    assert_equal Domgen::Naming.underscore('ThisIsCamelCased'), 'this_is_camel_cased'
    assert_equal Domgen::Naming.underscore('this_Is_Camel_Cased'), 'this_is_camel_cased'
    assert_equal Domgen::Naming.underscore('this_Is_camel_cased'), 'this_is_camel_cased'
    assert_equal Domgen::Naming.underscore('EJB'), 'ejb'
    assert_equal Domgen::Naming.underscore('EJBContainer'), 'ejb_container'
    assert_equal Domgen::Naming.underscore('_someField'), 'some_field'

    assert_equal Domgen::Naming.underscore?('some_field'), true
    assert_equal Domgen::Naming.underscore?('someField'), false
    assert_equal Domgen::Naming.underscore?(:some_field), true

    assert_equal Domgen::Naming.uppercase_constantize('thisIsCamelCased'), 'THIS_IS_CAMEL_CASED'
    assert_equal Domgen::Naming.uppercase_constantize('ThisIsCamelCased'), 'THIS_IS_CAMEL_CASED'
    assert_equal Domgen::Naming.uppercase_constantize('this_Is_Camel_Cased'), 'THIS_IS_CAMEL_CASED'
    assert_equal Domgen::Naming.uppercase_constantize('this_Is_camel_cased'), 'THIS_IS_CAMEL_CASED'
    assert_equal Domgen::Naming.uppercase_constantize('EJB'), 'EJB'
    assert_equal Domgen::Naming.uppercase_constantize('EJBContainer'), 'EJB_CONTAINER'
    assert_equal Domgen::Naming.uppercase_constantize('_someField'), 'SOME_FIELD'

    assert_equal Domgen::Naming.uppercase_constantize?('EJB_CONTAINER'), true
    assert_equal Domgen::Naming.uppercase_constantize?('someField'), false
    assert_equal Domgen::Naming.uppercase_constantize?(:EJB_CONTAINER), true

    assert_equal Domgen::Naming.kebabcase('thisIsCamelCased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.kebabcase('ThisIsCamelCased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.kebabcase('this_Is_Camel_Cased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.kebabcase('this_Is_camel_cased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.kebabcase('EJB'), 'ejb'
    assert_equal Domgen::Naming.kebabcase('EJBContainer'), 'ejb-container'
    assert_equal Domgen::Naming.kebabcase('_someField'), 'some-field'

    assert_equal Domgen::Naming.kebabcase?('ejb-container'), true
    assert_equal Domgen::Naming.kebabcase?('ejbContainer'), false
    assert_equal Domgen::Naming.kebabcase?(:'ejb-container'), true

    assert_equal Domgen::Naming.xmlize('thisIsCamelCased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.xmlize('ThisIsCamelCased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.xmlize('this_Is_Camel_Cased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.xmlize('this_Is_camel_cased'), 'this-is-camel-cased'
    assert_equal Domgen::Naming.xmlize('EJB'), 'ejb'
    assert_equal Domgen::Naming.xmlize('EJBContainer'), 'ejb-container'
    assert_equal Domgen::Naming.xmlize('_someField'), 'some-field'

    assert_equal Domgen::Naming.xmlize?('ejb-container'), true
    assert_equal Domgen::Naming.xmlize?('ejbContainer'), false
    assert_equal Domgen::Naming.xmlize?(:'ejb-container'), true

    assert_equal Domgen::Naming.jsonize('thisIsCamelCased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.jsonize('ThisIsCamelCased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.jsonize('this_Is_Camel_Cased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.jsonize('this_Is_camel_cased'), 'thisIsCamelCased'
    assert_equal Domgen::Naming.jsonize('EJB'), 'ejb'
    assert_equal Domgen::Naming.jsonize('EJBContainer'), 'ejbContainer'
    assert_equal Domgen::Naming.jsonize('_someField'), 'someField'

    assert_equal Domgen::Naming.jsonize?('ejbContainer'), true
    assert_equal Domgen::Naming.jsonize?('this_Is_Camel_Cased'), false
    assert_equal Domgen::Naming.jsonize?(:ejbContainer), true
  end

  def test_split_into_words
    assert_equal %w(my Support Library), Domgen::Naming.split_into_words('mySupportLibrary')
    assert_equal %w(My Support Library), Domgen::Naming.split_into_words('MySupportLibrary')
    assert_equal %w(my support library), Domgen::Naming.split_into_words('my-support-library')
    assert_equal %w(my support library), Domgen::Naming.split_into_words('my_support_library')
    assert_equal %w(MY SUPPORT LIBRARY), Domgen::Naming.split_into_words('MY_SUPPORT_LIBRARY')

    assert_equal %w(Find By ID), Domgen::Naming.split_into_words('FindByID')
  end

  def test_conversions
    perform_check(:camelize, 'mySupportLibrary')
    perform_check(:pascal_case, 'MySupportLibrary')
    perform_check(:xmlize, 'my-support-library')
    perform_check(:underscore, 'my_support_library')
    perform_check(:jsonize, 'mySupportLibrary')
    perform_check(:jsonize, 'mySupportLibrary')
    perform_check(:uppercase_constantize, 'MY_SUPPORT_LIBRARY')
  end

  def perform_check(method_name, result)
    assert_equal result, Domgen::Naming.send(method_name, 'MySupportLibrary'), "Checking conversion to #{result}"
    assert_equal result, Domgen::Naming.send(method_name, 'my_support_library'), "Checking conversion to #{result}"
    assert_equal result, Domgen::Naming.send(method_name, 'my-support-library'), "Checking conversion to #{result}"
    assert_equal result, Domgen::Naming.send(method_name, :'MySupportLibrary'), "Checking conversion to #{result}"
    assert_equal result, Domgen::Naming.send(method_name, :'my_support_library'), "Checking conversion to #{result}"
    assert_equal result, Domgen::Naming.send(method_name, :'my-support-library'), "Checking conversion to #{result}"
    assert_equal Domgen::Naming.send(:"#{method_name}?", result), true
    assert_equal Domgen::Naming.send(:"#{method_name}?", result.to_sym), true
  end
end
