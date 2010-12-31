module Domgen
  module Jpa
    module Helper
      def j_jpa_field_attributes(attribute)
        s = ''
        if !attribute.persistent?
          s << "  @javax.persistence.Transient\n"
        else
          s << "  @javax.persistence.Id\n" if attribute.primary_key?
          s << "  @javax.persistence.GeneratedValue( strategy = javax.persistence.GenerationType.IDENTITY )\n" if attribute.generated_value?
          if attribute.reference?
            s << "  @javax.persistence.ManyToOne( optional = #{attribute.nullable?} )\n"
            s << "  @javax.persistence.JoinColumn( name = \"#{attribute.sql.column_name}\", nullable = #{attribute.nullable?}, updatable = #{!attribute.immutable?} )\n"
          else
            s << "  @javax.persistence.Column( name = \"#{attribute.sql.column_name}\""
            s << ", length = #{attribute.length}" if attribute.has_non_max_length?
            s << ", nullable = #{attribute.nullable?}, updatable = #{!attribute.immutable?} )\n"
          end
        end
        s << "  @javax.validation.constraints.NotNull\n" if !attribute.nullable? && !attribute.generated_value?
        s << nullable_annotate(attribute, '')
        if attribute.attribute_type == :string
          unless attribute.length.nil? && attribute.min_length.nil?
            s << "  @javax.validation.constraints.Size( "
            s << "min = #{attribute.min_length} " unless attribute.min_length.nil?
            s << ", " unless attribute.min_length.nil? || !attribute.has_non_max_length?
            s << "max = #{attribute.length} " if attribute.has_non_max_length?
            s << " )\n"
          end
          if !attribute.allow_blank?
            s << "  @org.hibernate.validator.constraints.NotEmpty\n"
          end
        end
        s
      end

      def j_declared_relation(attribute)
        if attribute.inverse_relationship_type == :has_many
          type = attribute.object_type.java.fully_qualified_name
          s = ''
          s << "  @javax.persistence.OneToMany( mappedBy = \"#{attribute.name}\" )\n"
          s << "  private java.util.List<#{type}> #{pluralize(attribute.inverse_relationship_name)};\n"
          s
        elsif attribute.inverse_relationship_type == :has_one
          type = attribute.object_type.java.fully_qualified_name
          s = ''
          s << "  @javax.persistence.OneToOne( mappedBy= \"#{attribute.java.field_name}\")\n"
          s << "  private #{type} #{attribute.inverse_relationship_name};\n"
          s
        end
      end

      def j_declared_attribute_accessors(object_type)
        object_type.declared_attributes.collect do |attribute|
          if attribute.abstract?
            j_abstract_attribute(attribute)
          elsif attribute.reference?
            j_reference_attribute(attribute)
          else
            j_simple_attribute(attribute)
          end
        end.compact.join("\n")
      end

      def j_declared_attribute_and_relation_accessors(object_type)
        relation_methods = object_type.referencing_attributes.collect do |attribute|

          if attribute.abstract? || attribute.inherited? || attribute.inverse_relationship_type == :none
            # Ignore abstract attributes as will appear in child classes
            # Ignore inherited attributes as appear in parent class
            # Ignore attributes that have no inverse relationship
            nil
          elsif attribute.inverse_relationship_type == :has_many
            j_has_many_attribute(attribute)
          elsif attribute.inverse_relationship_type == :has_one
            name = attribute.inverse_relationship_name
            type = nullable_annotate(attribute, attribute.object_type.java.fully_qualified_name)

            java = description_javadoc_for attribute
            java << <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
            java
          end
        end
        j_declared_attribute_accessors(object_type) + relation_methods.compact.join("\n")
      end

      def j_return_if_value_same(name, primitive, nullable)
        if primitive
          return <<JAVA
     if( #{name} == value )
     {
       return;
     }
JAVA
        elsif !nullable
          return <<JAVA
     //noinspection ConstantConditions
     if( null == value )
     {
       throw new NullPointerException( "#{name} parameter is not nullable" );
     }

     if( value.equals( #{name} ) )
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

      def j_simple_attribute(attribute)
        name = attribute.java.field_name
        type = nullable_annotate(attribute, attribute.java.java_type)
        java = description_javadoc_for attribute
        java<< <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
#{j_return_if_value_same(name, attribute.java.primitive?, attribute.nullable?)}
        #{name} = value;
  }
JAVA
      java
      end

      def j_add_to_inverse(attribute)
        name = attribute.java.field_name
        inverse_name = attribute.inverse_relationship_name
        if attribute.inverse_relationship_type == :none
          ''
        elsif attribute.inverse_relationship_type == :has_many
          null_guard(attribute.nullable?, name) { "#{name}.add#{inverse_name}( this );" }
        else
          null_guard(attribute.nullable?, name) { "#{name}.set#{inverse_name}( this );" }
        end
      end

      def j_remove_from_inverse(attribute)
        name = attribute.java.field_name
        inverse_name = attribute.inverse_relationship_name
        if attribute.inverse_relationship_type == :none
          ''
        elsif attribute.inverse_relationship_type == :has_many
          null_guard(true, name) { "#{name}.remove#{inverse_name}( this );" }
        else
          null_guard(attribute.nullable?, name) { "#{name}.set#{inverse_name}( null );" }
        end
      end

      def j_reference_attribute(attribute)
        name = attribute.java.field_name
        type = nullable_annotate(attribute, attribute.java.java_type)
        java = description_javadoc_for attribute
        java << <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
 #{j_return_if_value_same(name, attribute.referenced_object.primary_key.java.primitive?, attribute.nullable?)}
        #{j_remove_from_inverse(attribute)}
        #{name} = value;
 #{j_add_to_inverse(attribute)}
  }
JAVA
      end

      def j_abstract_attribute(attribute)
        <<JAVA
    public abstract #{attribute.java.java_type} #{getter_for(attribute)};
JAVA
      end

      def j_has_many_attribute(attribute)
        name = attribute.inverse_relationship_name
        plural_name = pluralize(name)
        type = attribute.object_type.java.fully_qualified_name
        java = description_javadoc_for attribute
        java << <<STR
  public java.util.List<#{type}> get#{plural_name}()
  {
    return java.util.Collections.unmodifiableList( safeGet#{plural_name}() );
  }

  protected final void add#{name}( final #{type} value )
  {
    safeGet#{plural_name}().add( value );
  }

  protected final void remove#{name}( final #{type} value )
  {
    safeGet#{plural_name}().remove( value );
  }

  private java.util.List<#{type}> safeGet#{plural_name}()
  {
    if( null == #{plural_name} )
    {
      #{plural_name} = new java.util.LinkedList<#{type}>();
    }
    return #{plural_name};
  }
STR
        java
      end

      def j_equals_method(object_type)
        return '' if object_type.abstract?
        pk = object_type.primary_key
        pk_getter = getter_for(pk)
        pk_type = nullable_annotate(pk, pk.java.java_type)
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
      final #{pk_type} key = #{pk_getter};
      return null != key && key.equals( that.#{pk_getter} );
    }
  }

  @Override
  public int hashCode()
  {
    final #{pk_type} key = #{pk_getter};
    if( null == key )
    {
      return System.identityHashCode( this );
    }
    else
    {
      return key.hashCode();
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
        s += object_type.java.debug_attributes.collect do |a|
          attr = object_type.attribute_by_name(a)
          "           \"#{attr.java.field_name} = \" + " + getter_for(attr)
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
    return String.valueOf( #{getter_for(label)} );
JAVA
        else
          pk = object_type.primary_key
          s += <<JAVA
    return "#{object_type.name}[#{pk.java.field_name} = " + #{getter_for(pk)} +"]";
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
        s
      end

      def nullable_annotate(attribute, type)
        # Not sure why PrimaryKeys can not have annotation other than the fact that EclipseLink fails
        # to find ID if it is
        if attribute.java.primitive? || attribute.primary_key?
          type
        elsif !attribute.nullable? && !attribute.generated_value?
          "  @org.jetbrains.annotations.NotNull #{type}\n"
        else
          "  @org.jetbrains.annotations.Nullable #{type}\n"
        end
      end

      def null_guard(nullable, name)
        s = ''
        if nullable
          s += <<JAVA
  if( null != #{name} )
  {
JAVA
        end
        s += yield
        if nullable
          s += <<JAVA
  }
JAVA
        end
        s
      end


      def description_javadoc_for(attribute)
        description = attribute.tags[:Description]
        java = ''
        unless description.nil?
          java << <<JAVADOC
  /**
   * #{description}
   */
JAVADOC
        end
        java
      end

      def getter_for( attr )
        (attr.attribute_type == :boolean ? "is#{attr.java.field_name}()" : "get#{attr.java.field_name}()")
      end

    end
  end
end
