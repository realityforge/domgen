def java_getter_name(name)
  "get#{name}"
end

def java_setter_name(name)
  "set#{name}"
end

def java_getter(name,type)
  <<JAVA
  public #{type} #{java_getter_name(name)}()
  {
     return #{name};
  }
JAVA
end

def java_setter(name,type)
  <<JAVA
  public void #{java_setter_name(name)}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
end

def java_accessors(name,type)
  "#{java_getter(name,type)}\n#{java_setter(name,type)}"
end

def j_declared_attributes_and_relations(object_type)
  accessor_methods = object_type.declared_attributes.collect do |attribute|
    if attribute.abstract?
      j_abstract_attribute(attribute)
    elsif attribute.reference?
      j_reference_attribute(attribute)
    else
      j_simple_attribute(attribute)
    end
  end

  #attribute.reference? && !attribute.abstract? && !attribute.inherited?
  relation_methods = object_type.referencing_attributes.collect do |attribute|
    if attribute.abstract? || attribute.inherited? || attribute.inverse_relationship_type == :none
      # Ignore abstract attributes as will appear in child classes
      # Ignore inherited attributes as appear in parent class
      # Ignore attributes that have no inverse relationship
      ''
    elsif attribute.inverse_relationship_type == :has_many
      j_has_many_attribute(attribute)
    elsif attribute.inverse_relationship_type == :has_one
      java_accessors(attribute.inverse_relationship_name, attribute.object_type.java.fully_qualified_name)
    end
  end
  (accessor_methods + relation_methods).join("\n")
end

def j_simple_attribute(attribute)
  name = attribute.java.field_name
  type = attribute.java.java_type
  <<JAVA
  public #{type} get#{name}()
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
end

def j_reference_attribute(attribute)
  name = attribute.java.field_name
  type = attribute.java.java_type
  <<JAVA
  public #{type} get#{name}()
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
end

def j_abstract_attribute(attribute)
  <<JAVA
    public abstract #{attribute.java.java_type} get#{attribute.java.field_name}();
JAVA
end

def j_has_many_attribute(attribute)
  name = attribute.inverse_relationship_name
  plural_name = pluralize(name)
  type = attribute.object_type.java.fully_qualified_name
  <<STR
  public java.util.Set<#{type}> get#{plural_name}()
  {
    return java.util.Collections.unmodifiableSet( safeGet#{plural_name}() );
  }

  protected final void add#{name}( final #{type} value )
  {
    safeGet#{plural_name}().add( value );
  }

  protected final void remove#{name}( final #{type} value )
  {
    safeGet#{plural_name}().remove( value );
  }

  private java.util.Set<#{type}> safeGet#{plural_name}()
  {
    if( null == #{plural_name} )
    {
      #{plural_name} = new java.util.HashSet<#{type}>();
    }
    return #{plural_name};
  }
STR
end

def j_equals_method(object_type)
  return '' if object_type.abstract?
<<JAVA
  @Override
  public boolean equals( final Object o )
  {
    if ( this == o )
    {
      return true;
    }
    else if ( o == null || getClass() != o.getClass() )
    {
      return false;
    }
    else
    {
      final #{object_type.java.classname} that = (#{object_type.java.classname}) o;
      return getID() != null && getID().equals( that.getID() );
    }
  }
JAVA
end

def j_to_string_methods(object_type)
  return '' if object_type.abstract?
  s = <<JAVA
  public String toDebugString()
  {
    return "#{object_type.name}[" +
JAVA
  object_type.java.debug_attributes.each do |a|
    attr = object_type.attribute_by_name(a)
    s += <<JAVA
           "#{attr.java.field_name} = " + get#{attr.java.field_name}() +
JAVA
  end
  
  s += <<JAVA
           "]";
  }
JAVA
  s += <<JAVA
  public String toLabel()
  {
JAVA

  if !object_type.java.label_attribute.nil?
    label = object_type.attribute_by_name(object_type.java.label_attribute)
    s += <<JAVA
    return String.valueOf( get#{label.java.field_name}() );
JAVA
  else
    pk = object_type.primary_key
    s += <<JAVA
    return "#{object_type.name}[#{pk.java.field_name} = " + get#{pk.java.field_name}() +"]";    
JAVA
  end

  s += <<JAVA
  }

  @Override
  public String toString()
  {
    return #{!object_type.java.label_attribute.nil? ? 'toLabel' : 'toDebugString'}();
  }
JAVA
end

