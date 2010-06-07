module IrisHelper
  def iris_immutable_check(name)
    <<JAVA
    if( !isNew() && !isLoading() )
    {
       throw new IllegalStateException( "Attempting to modify immutable attribute #{name} on non-new object" );
    }
JAVA
  end

  def iris_nullable_check(name)
    <<JAVA
      if( !isUnloading() && null == value )
      {
         throw new IllegalStateException( "Attempting to null non-nullable attribute #{name}" );
      }
JAVA
  end

  def iris_to_string_methods(object_type)
    return '' if object_type.abstract?
    s = <<JAVA
  public String toDebugString()
  {
    return "#{object_type.name}[" +
JAVA
    s += object_type.java.debug_attributes.collect do |a|
      attr = object_type.attribute_by_name(a)
      accessor = attr.reference? ? attr.referencing_link_name : attr.java.field_name
      "           \"#{accessor} = \" + get#{accessor}()"
    end.join(" + \", \" +\n")

    s += <<JAVA
 +
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
end

