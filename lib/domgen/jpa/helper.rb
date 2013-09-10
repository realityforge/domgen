#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Domgen
  module JPA
    module Helper
      def j_jpa_field_attributes(attribute)
        s = ''
        s << "  @javax.persistence.Id\n" if attribute.primary_key?
        s << "  @javax.persistence.GeneratedValue( strategy = javax.persistence.GenerationType.IDENTITY )\n" if attribute.sql.identity?
        s << gen_relation_annotation(attribute, true) if attribute.reference?
        s << gen_column_annotation(attribute)
        s << "  @javax.persistence.Basic( optional = #{attribute.nullable?}, fetch = javax.persistence.FetchType.EAGER )\n" unless attribute.reference?
        s << "  @javax.persistence.Enumerated( javax.persistence.EnumType.#{ attribute.enumeration.numeric_values? ? "ORDINAL" : "STRING"} )\n" if attribute.enumeration?
        s << "  @javax.persistence.Temporal( javax.persistence.TemporalType.#{attribute.datetime? ? "TIMESTAMP" : "DATE"} )\n" if attribute.datetime? || attribute.date?
        s << "  @javax.validation.constraints.NotNull\n" if !attribute.nullable? && !attribute.generated_value?
        s << nullable_annotate(attribute, '', true)
        if attribute.text?
          unless attribute.length.nil? && attribute.min_length.nil?
            s << "  @javax.validation.constraints.Size( "
            s << "min = #{attribute.min_length} " unless attribute.min_length.nil?
            s << ", " unless attribute.min_length.nil? || !attribute.has_non_max_length?
            s << "max = #{attribute.length} " if attribute.has_non_max_length?
            s << " )\n"
          end
        end
        s
      end

      def j_declared_relation(attribute)
        s = ''
        s << gen_relation_annotation(attribute, false)
        s << gen_fetch_mode_if_specified(attribute)
        if attribute.inverse.multiplicity == :many
          s << "  private java.util.List<#{attribute.entity.jpa.qualified_name}> #{Domgen::Naming.pluralize(attribute.inverse.relationship_name)};\n"
        else # attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
          s << "  private #{attribute.entity.jpa.qualified_name} #{attribute.inverse.relationship_name};\n"
        end
        s
      end

      def gen_column_annotation(attribute)
        parameters = []
        parameters << "name = \"#{attribute.sql.column_name}\""
        parameters << "nullable = #{attribute.nullable?}"
        parameters << "updatable = #{attribute.updatable?}"
        parameters << "unique = #{attribute.unique?}"
        parameters << "insertable = #{!attribute.generated_value? || attribute.primary_key?}"

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
          parameters << "mappedBy = \"#{attribute.jpa.field_name}\""
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

      def j_constructors(entity)
        immutable_attributes = entity.attributes.select{|a| a.immutable? && !a.generated_value? && a.jpa.persistent? }
        declared_attribute_names = entity.declared_attributes.collect{|a| a.name}
        declared_immutable_attributes = immutable_attributes.select{ |a| declared_attribute_names.include?(a.name) }
        undeclared_immutable_attributes = immutable_attributes.select{ |a| !declared_attribute_names.include?(a.name) }
        return '' if immutable_attributes.empty?
        java = <<JAVA
  protected #{entity.jpa.name}()
  {
  }

  @SuppressWarnings( { "ConstantConditions", "deprecation" } )
  public #{entity.jpa.name}(#{immutable_attributes.collect{|a| "final #{nullable_annotate(a, a.jpa.java_type, false)} #{a.jpa.name}"}.join(", ")})
  {
#{undeclared_immutable_attributes.empty? ? '' : "    super(#{undeclared_immutable_attributes.collect{|a| a.jpa.name}.join(", ")});\n"}
#{declared_immutable_attributes.select{|a|!a.nullable? && !a.jpa.primitive?}.collect{|a| "    if( null == #{a.jpa.name} )\n    {\n      throw new NullPointerException( \"#{a.jpa.name} is not nullable\" );\n    }"}.join("\n")}
#{declared_immutable_attributes.collect { |a| "    this.#{a.jpa.field_name} = #{a.jpa.name};" }.join("\n")}
#{declared_immutable_attributes.select{|a|a.reference?}.collect { |a| "    " + j_add_to_inverse(a) }.join("\n")}
  }
JAVA
        java
      end

      def j_declared_attribute_accessors(entity)
        entity.declared_attributes.select{|attribute| attribute.jpa.persistent? }.collect do |attribute|
          if attribute.abstract?
            j_abstract_attribute(attribute)
          elsif attribute.reference?
            j_reference_attribute(attribute)
          else
            j_simple_attribute(attribute)
          end
        end.compact.join("\n")
      end

      def j_declared_attribute_and_relation_accessors(entity)
        relation_methods = entity.referencing_attributes.collect do |attribute|

          if attribute.abstract? || attribute.inherited? || !attribute.entity.jpa? || !attribute.jpa.persistent? || !attribute.inverse.jpa.traversable? || attribute.referenced_entity != entity
            # Ignore abstract attributes as will appear in child classes
            # Ignore inherited attributes as appear in parent class
            # Ignore attributes that have no inverse relationship
            nil
          elsif attribute.inverse.multiplicity == :many
            j_has_many_attribute(attribute)
          else #attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
            name = attribute.inverse.relationship_name
            field_name = entity.to_field_name( name )
            type = nullable_annotate(attribute, attribute.entity.jpa.qualified_name, false, true)

            java = description_javadoc_for attribute
            java << <<JAVA
  public #{type} #{getter_for(attribute, name)}
  {
     #{attribute.primary_key? ? "":"verifyNotRemoved();"}
     return #{field_name};
  }

  #{j_deprecation_warning(attribute)}final void add#{name}( final #{type} value )
  {
     #{attribute.primary_key? ? "":"verifyNotRemoved();"}
    if( null != #{field_name} )
    {
      throw new IllegalStateException("Attempted to add value when non null value exists.");
    }
    if( value != #{field_name} )
    {
      #{field_name} = value;
    }
  }

  public final void remove#{name}( final #{type} value )
  {
     #{attribute.primary_key? ? "":"verifyNotRemoved();"}
    if( null != #{field_name} && value != #{field_name} )
    {
      throw new IllegalStateException("Attempted to remove value that was not the same.");
    }
    if( null != #{field_name} )
    {
      #{field_name} = null;
    }
  }
JAVA
            java
          end
        end
        j_declared_attribute_accessors(entity) + relation_methods.compact.join("\n")
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
        field_name = attribute.jpa.field_name
        type = nullable_annotate(attribute, attribute.jpa.java_type, false)
        java = description_javadoc_for attribute
        java << <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     #{attribute.primary_key? ? "":"verifyNotRemoved();"}
JAVA
        if attribute.generated_value? && !attribute.nullable?
          java << <<JAVA
      if( null == #{field_name} )
      {
        throw new IllegalStateException("Attempting to access generated value #{name} before it has been flushed to the database.");
      }
JAVA

        end
        java << <<JAVA
     return doGet#{name}();
  }

  protected #{type} doGet#{name}()
  {
    return #{field_name};
  }

JAVA
        if attribute.updatable?
          java << <<JAVA
  public void set#{name}( final #{type} value )
  {
#{j_return_if_value_same(field_name, attribute.jpa.primitive?, attribute.nullable?)}
        #{field_name} = value;
  }
JAVA
        end
        java
      end

      def j_add_to_inverse(attribute)
        name = attribute.jpa.name
        field_name = attribute.jpa.field_name
        inverse_name = attribute.inverse.relationship_name
        if !attribute.inverse.jpa.traversable?
          ''
        else
          null_guard(attribute.nullable?, field_name) { "this.#{field_name}.add#{inverse_name}( this );" }
        end
      end

      def j_remove_from_inverse(attribute)
        name = attribute.jpa.name
        field_name = attribute.jpa.field_name
        inverse_name = attribute.inverse.relationship_name
        if !attribute.inverse.jpa.traversable?
          ''
        else
          null_guard(true, field_name) { "#{field_name}.remove#{inverse_name}( this );" }
        end
      end

      def j_reference_attribute(attribute)
        name = attribute.jpa.name
        field_name = attribute.jpa.field_name
        type = nullable_annotate(attribute, attribute.jpa.java_type, false)
        java = description_javadoc_for attribute
        java << <<JAVA
  public #{type} #{getter_for(attribute)}
  {
     #{attribute.primary_key? ? "":"verifyNotRemoved();"}
     return doGet#{attribute.jpa.name}();
  }

  protected #{type} doGet#{attribute.jpa.name}()
  {
    return #{field_name};
  }

JAVA
        if attribute.updatable?
          java << <<JAVA
  @SuppressWarnings( { "deprecation" } )
  public void set#{name}( final #{type} value )
  {
 #{j_return_if_value_same(field_name, attribute.referenced_entity.primary_key.jpa.primitive?, attribute.nullable?)}
        #{j_remove_from_inverse(attribute)}
        #{field_name} = value;
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

      def j_deprecation_warning(attribute)
        if attribute.entity.data_module.name != entity.data_module.name
          <<STR
  /**
   * This method should not be called directly. It is called from the constructor of #{attribute.entity.jpa.qualified_name}.
   * @deprecated
   */
  @Deprecated public
STR
        else
          ''
        end
      end

      def j_has_many_attribute(attribute)
        name = attribute.inverse.relationship_name
        plural_name = Domgen::Naming.pluralize(name)
        type = attribute.entity.jpa.qualified_name
        java = description_javadoc_for attribute
        java << <<STR
  public java.util.List<#{type}> get#{plural_name}()
  {
    return java.util.Collections.unmodifiableList( safeGet#{plural_name}() );
  }

  #{j_deprecation_warning(attribute)} final void add#{name}( final #{type} value )
  {
    final java.util.List<#{type}> #{plural_name} = safeGet#{plural_name}();
    if ( !#{plural_name}.contains( value ) )
    {
      #{plural_name}.add( value );
    }
  }

  public final void remove#{name}( final #{type} value )
  {
    if ( null != #{plural_name} && #{plural_name}.contains( value ) )
    {
      #{plural_name}.remove( value );
    }
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

      def j_equals_method(entity)
        return '' if entity.abstract?
        pk = entity.primary_key
        pk_getter = "doGet#{entity.primary_key.jpa.name}()"
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
    else if ( o == null || !(o instanceof #{entity.jpa.name}) )
    {
      return false;
    }
    else
    {
      final #{entity.jpa.name} that = (#{entity.jpa.name}) o;
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

      def j_to_string_methods(entity)
        return '' if entity.abstract?
        s = <<JAVA
  @Override
  public String toString()
  {
    return "#{entity.name}[" +
JAVA
        s += entity.attributes.select{|a| a.jpa.persistent?}.collect do |a|
          "           \"#{a.jpa.name} = \" + doGet#{a.jpa.name}()"
        end.join(" + \", \" +\n")
        s += <<JAVA
 +
           "]";
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
          annotation = "#{nullability_annotation(false)} #{type}"
        else
          annotation = "#{nullability_annotation(true)} #{type}"
        end
        if is_field_annotation
          "  #{annotation}\n"
        else
          annotation
        end
      end

      def query_return_type(query)
        return "int" if query.query_type != :select
        name = query.entity.jpa.qualified_name
        return "#{nullability_annotation(false)} java.util.List<#{name}>" if query.multiplicity == :many
        "#{nullability_annotation(query.multiplicity == :zero_or_one)} #{name}"
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

      def getter_for( attribute, name = nil )
        name = attribute.jpa.name unless name
        "#{getter_prefix(attribute)}#{name}()"
      end

    end
  end
end
