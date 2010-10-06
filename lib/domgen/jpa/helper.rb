module Domgen
  module Jpa
    module Helper
      def j_class_definition(object_type)
        s = "public "
        s << "abstract " if object_type.abstract?
        s << "class #{object_type.java.classname}\n"
        if object_type.extends
          s << "    extends #{object_type.schema.object_type_by_name(object_type.extends).java.classname}\n"
        end
        s
      end

      def j_declared_fields(object_type)
        object_type.declared_attributes.collect { |a| j_declared_field(a) }.compact.join("\n")
      end

      def j_jpa_field_attributes(attribute)
        s = ''
        if !attribute.persistent?
          s << "  @Transient\n"
        else
          s << "  @Id\n" if attribute.primary_key?
          s << "  @GeneratedValue( strategy = GenerationType.IDENTITY )\n" if attribute.generated_value?

          if attribute.reference?
            s << "  @ManyToOne( optional = #{attribute.nullable?} )\n"
            s << "  @JoinColumn( name = \"#{attribute.sql.column_name}\", nullable = #{attribute.nullable?}, updatable = #{!attribute.immutable?} )\n"
          else
            s << "  @Column( name = \"#{attribute.sql.column_name}\""
            s << ", length = #{attribute.length}" if !attribute.length.nil?
            s << ", nullable = #{attribute.nullable?}, updatable = #{!attribute.immutable?} )\n"
          end
        end
        s << "  @NotNull\n" if !attribute.nullable? && !attribute.generated_value?
        s << "  @Size( max = #{attribute.length} )\n" if !attribute.length.nil?
        s
      end

      def j_declared_field(attribute)
        return nil if attribute.abstract?
        s = ''
        s << j_jpa_field_attributes(attribute)
        s << "  private #{attribute.java.java_type} #{attribute.java.field_name};\n"
        s
      end

      def j_declared_relations(object_type)
        object_type.referencing_attributes.collect { |a| j_declared_relation(a) }.compact.join("\n")
      end

      def j_declared_relation(attribute)
        if attribute.abstract? || attribute.inherited? || attribute.inverse_relationship_type == :none
          # Ignore abstract relations as will appear in child classes
          # Ignore inherited relations as appear in parent class
          # Ignore attributes that have no inverse relationship
          nil
        elsif attribute.inverse_relationship_type == :has_many
          type = attribute.object_type.java.fully_qualified_name
          s = ''
          s << "  @OneToMany( mappedBy = \"#{attribute.name}\" )\n"
          s << "  private java.util.List<#{type}> #{pluralize(attribute.inverse_relationship_name)};\n"
          s
        elsif attribute.inverse_relationship_type == :has_one
          type = attribute.object_type.java.fully_qualified_name
          s = ''
          s << "  @OneToOne(mappedBy= \"#{attribute.java.field_name}\")\n"
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
            type = attribute.object_type.java.fully_qualified_name
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

      def j_simple_attribute(attribute)
        name = attribute.java.field_name
        type = attribute.java.java_type
        return <<JAVA
  public #{type} get#{name}()
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
#{j_return_if_value_same(name, attribute.java.primitive?, attribute.nullable?)}
        #{name} = value;
  }
JAVA
      end

      def j_add_to_inverse(attribute)
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

      def j_remove_from_inverse(attribute)
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
 #{j_return_if_value_same(name, attribute.referenced_object.primary_key.java.primitive?, attribute.nullable?)}
        #{j_remove_from_inverse(attribute)}
        #{name} = value;
 #{j_add_to_inverse(attribute)}
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

  @Override
  public int hashCode()
  {
    if( getID() == null )
    {
      throw new IllegalStateException( "Do not attempt to use hashcode (e.g. in a set) without persisting first" );
    }
    return getID().hashCode();
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
          "           \"#{attr.java.field_name} = \" + get#{attr.java.field_name}()"
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
        return s
      end
    end
  end
end
