module Domgen
  module Iris
    module Helper
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

      def iris_attribute_type(attribute)
        attribute.reference? ? attribute.referenced_object.iris.classname : attribute.java.java_type
      end

      def iris_add_to_inverse(attribute)
        name = attribute.java.field_name
        inverse_name = attribute.inverse_relationship_name
        if attribute.inverse_relationship_type == :none
          ''
        elsif attribute.inverse_relationship_type == :has_many
        <<JAVA
      if( null != #{name} )
      {
        #{name}.add#{inverse_name}( this );
      }
JAVA
        else
          <<JAVA
      if( null != #{name} )
      {
        #{name}.set#{inverse_name}( this );
      }
JAVA
        end
      end

      def iris_remove_from_inverse(attribute)
        name = attribute.java.field_name
        inverse_name = attribute.inverse_relationship_name
        if attribute.inverse_relationship_type == :none
          ''
        elsif attribute.inverse_relationship_type == :has_many
        <<JAVA
      if( null != #{name} )
      {
        #{name}.remove#{inverse_name}( this );
      }
JAVA
        else
          <<JAVA
      if( null != #{name} )
      {
        #{name}.set#{inverse_name}( null );
      }
JAVA
        end
      end

      def iris_return_if_value_same(name, primitive, nullable)
        if primitive
          return <<JAVA
       if( #{name} == value )
       {
         return;
       }
JAVA
        elsif !nullable
          return <<JAVA
       if( null != #{name} && #{name}.equals( value ) )
       {
         return;
       }
JAVA
        else
          return <<JAVA
       if( null != #{name} && #{name}.equals( value ) )
       {
         return;
       }
       else if( null != value && value.equals( #{name} ) )
       {
         return;
       }
       else if( null == #{name} && null == value )
       {
         return;
       }
JAVA
        end
      end
    end
  end
end


