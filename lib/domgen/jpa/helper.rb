module Domgen
  module JPA
    module Helper
      def j_jpa_field_attributes(attribute)
        s = ''
        if !attribute.persistent?
          s << "  @javax.persistence.Transient\n"
        else
          s << "  @javax.persistence.Id\n" if attribute.primary_key?
          s << "  @javax.persistence.GeneratedValue( strategy = javax.persistence.GenerationType.AUTO )\n" if attribute.sql.identity?
          s << gen_relation_annotation(attribute, true) if attribute.reference?
          s << gen_column_annotation(attribute)
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
          s << "  @org.hibernate.validator.constraints.NotEmpty\n" if !attribute.allow_blank?
        end
        s
      end

      def j_declared_relation(attribute)
        s = ''
        s << gen_relation_annotation(attribute, false)
        s << gen_fetch_mode_if_specified(attribute)
        if attribute.inverse.multiplicity == :many
          s << "  private java.util.List<#{attribute.object_type.jpa.qualified_entity_name}> #{pluralize(attribute.inverse.relationship_name)};\n"
        else # attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
          s << "  private #{attribute.object_type.jpa.qualified_entity_name} #{attribute.inverse.relationship_name};\n"
        end
        s
      end

      def gen_column_annotation(attribute)
        parameters = []
        parameters << "name = \"#{attribute.sql.column_name}\""
        parameters << "nullable = #{attribute.nullable?}"
        parameters << "updatable = #{attribute.updatable?}"
        parameters << "unique = #{attribute.unique?}"
        parameters << "insertable = #{!attribute.generated_value?}"

        if !attribute.reference? && attribute.has_non_max_length?
          parameters << "length = #{attribute.length}"
        end

        annotation = attribute.reference? ? "JoinColumn" : "Column"
        "  @javax.persistence.#{annotation}( #{parameters.join(', ')} )\n"
      end

      def gen_relation_annotation(attribute, declaring_relationship)
        parameters = []
        cascade = declaring_relationship ? attribute.jpa.cascade : attribute.inverse.jpa.cascade
        unless cascade.nil? || cascade.empty?
          parameters << "cascade = { #{cascade.map { |c| "javax.persistence.CascadeType.#{c.to_s.upcase}" }.join(", ")} }"
        end

        fetch_type = declaring_relationship ? attribute.jpa.fetch_type : attribute.inverse.jpa.fetch_type
        parameters << "fetch = javax.persistence.FetchType.#{fetch_type.to_s.upcase}"

        if declaring_relationship
          parameters << "optional = #{attribute.nullable?}"
        end

        if !declaring_relationship
          parameters << "orphanRemoval = #{attribute.inverse.jpa.orphan_removal?}"
          parameters << "mappedBy = \"#{attribute.jpa.name}\""
        end

        #noinspection RubyUnusedLocalVariable
        annotation = nil
        if attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
          annotation = "OneToOne"
        elsif declaring_relationship
          annotation = "ManyToOne"
        else
          annotation = "OneToMany"
        end

        "  @javax.persistence.#{annotation}( #{parameters.join(", ")} )\n"
      end

      def gen_fetch_mode_if_specified(attribute)
        fetch_mode = attribute.inverse.jpa.fetch_mode
        if fetch_mode
          "  @org.hibernate.annotations.Fetch( org.hibernate.annotations.FetchMode.#{fetch_mode.to_s.upcase} )\n"
        else
          ''
        end
      end

      def j_constructors(object_type)
        immutable_attributes = object_type.attributes.select{|a| a.immutable? && !a.generated_value? && a.jpa.persistent? }
        declared_attribute_names = object_type.declared_attributes.collect{|a| a.name}
        declared_immutable_attributes = immutable_attributes.select{ |a| declared_attribute_names.include?(a.name) }
        undeclared_immutable_attributes = immutable_attributes.select{ |a| !declared_attribute_names.include?(a.name) }
        return '' if immutable_attributes.empty?
        java = <<JAVA
  protected #{object_type.jpa.entity_name}()
  {
  }

  @SuppressWarnings( { "ConstantConditions", "deprecation" } )
  public #{object_type.jpa.entity_name}(#{immutable_attributes.collect{|a| "final #{nullable_annotate(a, a.jpa.java_type, false)} #{a.jpa.name}"}.join(", ")})
  {
#{undeclared_immutable_attributes.empty? ? '' : "    super(#{undeclared_immutable_attributes.collect{|a| a.jpa.name}.join(", ")});\n"}
#{declared_immutable_attributes.select{|a|!a.nullable? && !a.jpa.primitive?}.collect{|a| "    if( null == #{a.jpa.name} )\n    {\n      throw new NullPointerException( \"#{a.jpa.name} is not nullable\" );\n    }"}.join("\n")}
#{declared_immutable_attributes.collect { |a| "    this.#{a.jpa.name} = #{a.jpa.name};" }.join("\n")}
#{declared_immutable_attributes.select{|a|a.reference?}.collect { |a| "    " + j_add_to_inverse(a) }.join("\n")}
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

          if attribute.abstract? || attribute.inherited? || !attribute.inverse.traversable? || !attribute.jpa.persistent? || attribute.referenced_object != object_type
            # Ignore abstract attributes as will appear in child classes
            # Ignore inherited attributes as appear in parent class
            # Ignore attributes that have no inverse relationship
            nil
          elsif attribute.inverse.multiplicity == :many
            j_has_many_attribute(attribute)
          else #attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
            name = attribute.inverse.relationship_name
            type = nullable_annotate(attribute, attribute.object_type.jpa.qualified_entity_name, false, true)

            java = description_javadoc_for attribute
            java << <<JAVA
  public #{type} #{getter_for(attribute, name)}
  {
     return #{name};
  }

  /**
   * This method should not be called directly. It is called from the constructor of #{type}.
   */
  @Deprecated
  public final void add#{name}( final #{type} value )
  {
    if( null != #{name}  )
    {
      throw new IllegalStateException("Attempted to add value when non null value exists.");
    }
    #{name} = value;
  }

  public final void remove#{name}( final #{type} value )
  {
    if( null != #{name} && value != #{name} )
    {
      throw new IllegalStateException("Attempted to remove value that was not the same.");
    }
    #{name} = null;
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
        name = attribute.jpa.name
        type = nullable_annotate(attribute, attribute.jpa.java_type, false)
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
#{j_return_if_value_same(name, attribute.jpa.primitive?, attribute.nullable?)}
        #{name} = value;
  }
JAVA
        end
        java
      end

      def j_add_to_inverse(attribute)
        name = attribute.jpa.name
        inverse_name = attribute.inverse.relationship_name
        if !attribute.inverse.traversable?
          ''
        else
          null_guard(attribute.nullable?, name) { "this.#{name}.add#{inverse_name}( this );" }
        end
      end

      def j_remove_from_inverse(attribute)
        name = attribute.jpa.name
        inverse_name = attribute.inverse.relationship_name
        if !attribute.inverse.traversable?
          ''
        else
          null_guard(true, name) { "#{name}.remove#{inverse_name}( this );" }
        end
      end

      def j_reference_attribute(attribute)
        name = attribute.jpa.name
        type = nullable_annotate(attribute, attribute.jpa.java_type, false)
        java = description_javadoc_for attribute
        java << <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     return #{name};
  }
JAVA
        if attribute.updatable?
          java << <<JAVA
  @SuppressWarnings( { "deprecation" } )
  public void set#{name}( final #{type} value )
  {
 #{j_return_if_value_same(name, attribute.referenced_object.primary_key.jpa.primitive?, attribute.nullable?)}
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
    public abstract #{attribute.jpa.java_type} #{getter_for(attribute)};
JAVA
      end

      def j_has_many_attribute(attribute)
        name = attribute.inverse.relationship_name
        plural_name = pluralize(name)
        type = attribute.object_type.jpa.qualified_entity_name
        java = description_javadoc_for attribute
        java << <<STR
  public java.util.List<#{type}> get#{plural_name}()
  {
    return java.util.Collections.unmodifiableList( safeGet#{plural_name}() );
  }

  /**
   * This method should not be called directly. It is called from the constructor of #{type}.
   */
  @Deprecated
  public final void add#{name}( final #{type} value )
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
        pk_type = nullable_annotate(pk, pk.jpa.java_type, false)
        equality_comparison = (!pk.jpa.primitive?) ? "null != key && key.equals( that.#{pk_getter} )" : "key == that.#{pk_getter}"
        s = <<JAVA
  @Override
  public boolean equals( final Object o )
  {
    if ( this == o )
    {
      return true;
    }
    else if ( o == null || !#{object_type.jpa.entity_name}.class.isInstance( o ) )
    {
      return false;
    }
    else
    {
      final #{object_type.jpa.entity_name} that = (#{object_type.jpa.entity_name}) o;
      final #{pk_type} key = #{pk_getter};
      return #{equality_comparison};
    }
  }
JAVA
        s += <<JAVA
  @Override
  public int hashCode()
  {
    final #{pk_type} key = #{pk_getter};
JAVA
        if pk.jpa.primitive?
          s += <<JAVA
    return key;
JAVA
        else
          s += <<JAVA
    if( null == key )
    {
      return System.identityHashCode( this );
    }
    else
    {
      return key.hashCode();
    }
JAVA
        end
        s += <<JAVA
  }
JAVA
        s
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
          "           \"#{a.jpa.name} = \" + " + getter_for(a)
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
    return "#{object_type.name}[#{pk.jpa.name} = " + #{getter_for(pk)} +"]";
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
        if attribute.jpa.primitive? || attribute.primary_key?
          return type
        elsif !attribute.nullable? &&
          !attribute.generated_value? &&
          !(attribute.reference? && attribute.inverse.multiplicity == :zero_or_one && inverse_side)
          annotation = "@javax.annotation.Nonnull #{type}"
        else
          annotation = "@javax.annotation.Nullable #{type}"
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
        field_name = attribute.jpa.name unless field_name
        (attribute.attribute_type == :boolean ? "is#{field_name}()" : "get#{field_name}()")
      end

    end
  end
end
