module Domgen
  module Jpa
    module Helper
      def j_jpa_field_attributes(attribute)
        s = ''
        if !attribute.persistent?
          s << "  @javax.persistence.Transient\n"
        else
          s << "  @javax.persistence.Id\n" if attribute.primary_key?
          s << "  @javax.persistence.GeneratedValue( strategy = javax.persistence.GenerationType.IDENTITY )\n" if attribute.sql.identity?
          if attribute.reference?
            if attribute.inverse_multiplicity == :one || attribute.inverse_multiplicity == :zero_or_one
              parameters = ["optional = #{attribute.nullable?}"]
              j_relation_parameters(attribute, parameters)
              s << "  @javax.persistence.ManyToOne( #{parameters.join(", ")} )\n"
              s << "  @javax.persistence.OneToOne( #{parameters.join(", ")} )\n"
            else # attribute.inverse_multiplicity == :many
              parameters = ["optional = #{attribute.nullable?}"]
              j_relation_parameters(attribute, parameters)
              s << "  @javax.persistence.ManyToOne( #{parameters.join(", ")} )\n"
            end
            s << "  @javax.persistence.JoinColumn( name = \"#{attribute.sql.column_name}\", nullable = #{attribute.nullable?}, updatable = #{attribute.updatable?} )\n"
          else
            s << "  @javax.persistence.Column( name = \"#{attribute.sql.column_name}\""
            s << ", length = #{attribute.length}" if attribute.has_non_max_length?
            s << ", nullable = #{attribute.nullable?}, updatable = #{attribute.updatable?} )\n"
          end
        end
        s << "  @javax.validation.constraints.NotNull\n" if !attribute.nullable? && !attribute.generated_value?
        s << nullable_annotate(attribute, '', true)
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

      def j_relation_parameters(attribute, parameters)
        cascade = attribute.jpa.cascade
        unless cascade.nil? || cascade.empty?
          parameters << "cascade = { #{cascade.map { |c| "javax.persistence.CascadeType.#{c.to_s.upcase}" }.join(", ")} }"
        end

        parameters << "fetch = javax.persistence.FetchType.#{attribute.jpa.fetch_type.to_s.upcase}"
      end

      def j_declared_relation(attribute)
        if attribute.inverse_multiplicity == :many
          type = attribute.object_type.java.qualified_name
          s = ''
          parameters = ["mappedBy = \"#{attribute.name}\""]

          j_relation_parameters(attribute, parameters)

          parameters << "orphanRemoval = true" if attribute.jpa.orphan_removal?
          s << "  @javax.persistence.OneToMany( #{parameters.join(", ")} )\n"
          fetch_mode = attribute.jpa.fetch_mode
          if fetch_mode
            s << "  @org.hibernate.annotations.Fetch( org.hibernate.annotations.FetchMode.#{fetch_mode.to_s.upcase} )\n"
          end
          s << "  private java.util.List<#{type}> #{pluralize(attribute.inverse_relationship_name)};\n"
          s
        else # attribute.inverse_multiplicity == :one || attribute.inverse_multiplicity == :zero_or_one
          type = attribute.object_type.java.qualified_name
          s = ''
          optional = (attribute.inverse_multiplicity == :zero_or_one) ? '' : ', optional = true'
          s << "  @javax.persistence.OneToOne( mappedBy= \"#{attribute.java.field_name}\"#{optional} )\n"
          s << "  private #{type} #{attribute.inverse_relationship_name};\n"
          s
        end
      end

      def j_constructors(object_type)
        immutable_attributes = object_type.attributes.select{|a| a.immutable? && !a.generated_value? && a.jpa.persistent? }
        return '' if immutable_attributes.empty?
        java = <<JAVA
  protected #{object_type.java.classname}()
  {
  }

  @SuppressWarnings( { "ConstantConditions" } )
  public #{object_type.java.classname}(#{immutable_attributes.collect{|a| "final #{nullable_annotate(a, a.java.java_type, false)} #{a.java.field_name}"}.join(", ")})
  {
#{immutable_attributes.select{|a|!a.nullable? && !a.java.primitive?}.collect{|a| "    if( null == #{a.java.field_name} )\n    {\n      throw new NullPointerException( \"#{a.java.field_name} is not nullable\" );\n    }"}.join("\n")}
#{immutable_attributes.collect { |a| "    this.#{a.java.field_name} = #{a.java.field_name};" }.join("\n")}
#{immutable_attributes.select{|a|a.reference?}.collect { |a| "    " + j_add_to_inverse(a) }.join("\n")}
  }
JAVA
        java
      end

      def j_declared_attribute_accessors(object_type)
        object_type.declared_attributes.select{|attribute| attribute.jpa.persistent? }.collect do |attribute|
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

          if attribute.abstract? || attribute.inherited? || !attribute.inverse_traversable? || !attribute.jpa.persistent?
            # Ignore abstract attributes as will appear in child classes
            # Ignore inherited attributes as appear in parent class
            # Ignore attributes that have no inverse relationship
            nil
          elsif attribute.inverse_multiplicity == :many
            j_has_many_attribute(attribute)
          else #attribute.inverse_multiplicity == :one || attribute.inverse_multiplicity == :zero_or_one
            name = attribute.inverse_relationship_name
            type = nullable_annotate(attribute, attribute.object_type.java.qualified_name, false, true)

            java = description_javadoc_for attribute
            java << <<JAVA
  public #{type} #{getter_for(attribute, name)}
  {
     return #{name};
  }
JAVA
            if attribute.updatable?
              java << <<JAVA
  public void set#{name}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
            end
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
        type = nullable_annotate(attribute, attribute.java.java_type, false)
        java = description_javadoc_for attribute
        java << <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     return #{name};
  }
JAVA
        if attribute.updatable?
          java << <<JAVA
  public void set#{name}( final #{type} value )
  {
#{j_return_if_value_same(name, attribute.java.primitive?, attribute.nullable?)}
        #{name} = value;
  }
JAVA
        end
        java
      end

      def j_add_to_inverse(attribute)
        name = attribute.java.field_name
        inverse_name = attribute.inverse_relationship_name
        if !attribute.inverse_traversable?
          ''
        elsif attribute.inverse_multiplicity == :many
          null_guard(attribute.nullable?, name) { "this.#{name}.add#{inverse_name}( this );" }
        else
          null_guard(attribute.nullable?, name) { "this.#{name}.set#{inverse_name}( this );" }
        end
      end

      def j_remove_from_inverse(attribute)
        name = attribute.java.field_name
        inverse_name = attribute.inverse_relationship_name
        if !attribute.inverse_traversable?
          ''
        elsif attribute.inverse_multiplicity == :many
          null_guard(true, name) { "#{name}.remove#{inverse_name}( this );" }
        else
          null_guard(attribute.nullable?, name) { "#{name}.set#{inverse_name}( null );" }
        end
      end

      def j_reference_attribute(attribute)
        name = attribute.java.field_name
        type = nullable_annotate(attribute, attribute.java.java_type, false)
        java = description_javadoc_for attribute
        java << <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     return #{name};
  }
JAVA
        if attribute.updatable?
          java << <<JAVA
  public void set#{name}( final #{type} value )
  {
 #{j_return_if_value_same(name, attribute.referenced_object.primary_key.java.primitive?, attribute.nullable?)}
        #{j_remove_from_inverse(attribute)}
        #{name} = value;
 #{j_add_to_inverse(attribute)}
  }
JAVA
        end
        java
      end

      def j_abstract_attribute(attribute)
        <<JAVA
    public abstract #{attribute.java.java_type} #{getter_for(attribute)};
JAVA
      end

      def j_has_many_attribute(attribute)
        name = attribute.inverse_relationship_name
        plural_name = pluralize(name)
        type = attribute.object_type.java.qualified_name
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

  public final void remove#{name}( final #{type} value )
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
        pk_type = nullable_annotate(pk, pk.java.java_type, false)
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

        debug_attributes =
          object_type.java.debug_attributes.collect {|a| object_type.attribute_by_name(a)}.select{|a| a.jpa.persistent?}

        s += debug_attributes.collect do |a|
          "           \"#{a.java.field_name} = \" + " + getter_for(a)
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

      def nullable_annotate(attribute, type, is_field_annotation, inverse_side = false)
        # Not sure why PrimaryKeys can not have annotation other than the fact that EclipseLink fails
        # to find ID if it is
        if attribute.java.primitive? || attribute.primary_key?
          return type
        elsif !attribute.nullable? &&
          !attribute.generated_value? &&
          !(attribute.reference? && attribute.inverse_multiplicity == :zero_or_one && inverse_side)
          annotation = "@org.jetbrains.annotations.NotNull #{type}"
        else
          annotation = "@org.jetbrains.annotations.Nullable #{type}"
        end
        if is_field_annotation
          "  #{annotation}\n"
        else
          annotation
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


      def description_javadoc_for(element, depth = "  ")
        description = element.tags[:Description]
        return '' unless description
        return <<JAVADOC
#{depth}/**
#{depth} * #{description.gsub(/\n+\Z/,"").gsub("\n\n","\n<br />\n").gsub("\n","\n#{depth} * ")}
#{depth} */
JAVADOC
      end

      def getter_for( attribute, field_name = nil )
        field_name = attribute.java.field_name unless field_name
        (attribute.attribute_type == :boolean ? "is#{field_name}()" : "get#{field_name}()")
      end

    end
  end
end
