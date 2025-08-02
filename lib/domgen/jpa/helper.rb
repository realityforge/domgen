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
        s << "  @SuppressWarnings( \"NotNullFieldNotInitialized\" )\n" if jpa_nullable_annotation?(attribute) && !jpa_nullable?(attribute)
        s << "  @javax.persistence.Id\n" if attribute.primary_key?
        if attribute.jpa.identity?
          s << "  @javax.persistence.GeneratedValue( strategy = javax.persistence.GenerationType.IDENTITY )\n"
        elsif attribute.jpa.sequence?
          s << "  @javax.persistence.GeneratedValue( strategy = javax.persistence.GenerationType.SEQUENCE, generator = \"#{attribute.jpa.generator_name}\" )\n"
          # Due to a bug in eclipselink the schema and sequence name attributes need to be quoted
          schema = attribute.sql.dialect.quote(attribute.entity.data_module.sql.schema).gsub("\"", '\\"')
          sequence_name = attribute.sql.dialect.quote(attribute.jpa.sequence_name).gsub("\"", '\\"')
          s << "  @javax.persistence.SequenceGenerator( name = \"#{attribute.jpa.generator_name}\", schema = \"#{schema}\", sequenceName = \"#{sequence_name}\", allocationSize = 1, initialValue = 1 )\n"
        elsif attribute.jpa.table_sequence?
          s << "  @javax.persistence.GeneratedValue( strategy = javax.persistence.GenerationType.TABLE, generator = \"#{attribute.jpa.generator_name}\" )\n"
          # Due to a bug in eclipselink the schema and sequence name attributes need to be quoted
          schema = attribute.sql.dialect.quote(attribute.entity.data_module.sql.schema).gsub("\"", '\\"')
          sequence_name = attribute.sql.dialect.quote(attribute.jpa.sequence_name).gsub("\"", '\\"')
          pk_column = attribute.sql.dialect.quote('Name')
          value_column = attribute.sql.dialect.quote('Value')
          s << "  @javax.persistence.TableGenerator( name = \"#{attribute.jpa.generator_name}\", schema = \"#{schema}\", table = \"#{sequence_name}\", pkColumnName = \"#{pk_column}\", valueColumnName=\"#{value_column}\", pkColumnValue=\"#{attribute.entity.name}\", allocationSize = 1, initialValue = 1 )\n"
        end
        s << gen_relation_annotation(attribute, true) if attribute.reference?
        s << gen_column_annotation(attribute)
        s << "  @javax.persistence.Basic( #{attribute.nullable? ? '' : 'optional = false, '}fetch = javax.persistence.FetchType.#{attribute.jpa.fetch_type.to_s.upcase} )\n" unless attribute.reference? || attribute.primary_key?
        s << "  @javax.persistence.Enumerated( javax.persistence.EnumType.#{ attribute.enumeration.numeric_values? ? 'ORDINAL' : 'STRING'} )\n" if attribute.enumeration?
        s << "  @javax.persistence.Temporal( javax.persistence.TemporalType.#{attribute.datetime? ? 'TIMESTAMP' : 'DATE'} )\n" if attribute.datetime? || attribute.date?
        s << "  @javax.validation.constraints.NotNull\n" if jpa_nullable_annotation?(attribute) && !jpa_nullable?(attribute)
        converter = attribute.jpa.converter
        s << "  @javax.persistence.Convert( converter = #{converter.gsub('$','.')}.class )\n" if converter

        if jpa_nullable_annotation?(attribute)
          s << "  #{nullability_annotation(jpa_nullable?(attribute))}\n"
        end

        if attribute.text?
          unless attribute.length.nil? && attribute.min_length.nil?
            s << '  @javax.validation.constraints.Size( '
            s << "min = #{attribute.min_length} " unless attribute.min_length.nil?
            s << ', ' unless attribute.min_length.nil? || !attribute.has_non_max_length?
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
          s << "  private java.util.List<#{attribute.entity.jpa.qualified_name}> #{Reality::Naming.camelize(Reality::Naming.pluralize(attribute.inverse.name))};\n"
        else # attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
          s << "  private #{attribute.entity.jpa.qualified_name} #{Reality::Naming.camelize(attribute.inverse.name)};\n"
        end
        s
      end

      def gen_column_annotation(attribute)
        parameters = []
        # nullable = true, updatable = true, unique = false, insertable = true
        parameters << "name = \"#{attribute.sql.column_name}\""
        parameters << "nullable = false" unless attribute.nullable?
        parameters << "updatable = false" unless attribute.updatable?
        parameters << "unique = true" if attribute.unique? || attribute.primary_key?
        parameters << "insertable = false" unless !attribute.generated_value? || attribute.primary_key?

        if attribute.reference?
          parameters << "referencedColumnName = \"#{attribute.referenced_entity.primary_key.sql.column_name}\""
        end

        if !attribute.reference? && attribute.has_non_max_length? && 255 != attribute.length
          parameters << "length = #{attribute.length}"
        end

        annotation = attribute.reference? ? 'JoinColumn' : 'Column'
        "  @javax.persistence.#{annotation}( #{parameters.join(', ')} )\n"
      end

      def gen_relation_annotation(attribute, declaring_relationship)
        parameters = []
        cascade = declaring_relationship ? attribute.jpa.cascade : attribute.inverse.jpa.cascade
        unless cascade.nil? || cascade.empty?
          parameters << "cascade = { #{cascade.map { |c| "javax.persistence.CascadeType.#{c.to_s.upcase}" }.join(', ')} }"
        end

        fetch_type = declaring_relationship ? attribute.jpa.fetch_type : attribute.inverse.jpa.fetch_type
        parameters << "fetch = javax.persistence.FetchType.#{fetch_type.to_s.upcase}"

        if declaring_relationship
          parameters << "optional = #{attribute.nullable?}"
          parameters << "targetEntity = #{attribute.referenced_entity.jpa.qualified_name}.class"
        end

        if !declaring_relationship
          parameters << "orphanRemoval = #{attribute.inverse.jpa.orphan_removal?}"
          parameters << "mappedBy = \"#{attribute.jpa.field_name}\""
          parameters << "targetEntity = #{attribute.entity.jpa.qualified_name}.class"
        end

        #noinspection RubyUnusedLocalVariable
        annotation = nil
        if attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
          annotation = 'OneToOne'
        elsif declaring_relationship
          annotation = 'ManyToOne'
        else
          annotation = 'OneToMany'
        end

        "  @javax.persistence.#{annotation}( #{parameters.join(', ')} )\n"
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
        immutable_attributes = entity.attributes.select{|a| a.immutable? && !a.generated_value? && a.jpa? && a.jpa.persistent? }
        declared_attribute_names = entity.declared_attributes.collect{|a| a.name}
        declared_immutable_attributes = immutable_attributes.select{ |a| declared_attribute_names.include?(a.name) }
        java = <<JAVA
  #{immutable_attributes.empty? ? 'public' : 'protected'} #{entity.jpa.name}()
  {
  }

JAVA
        return java if immutable_attributes.empty?
        java = java + <<JAVA
  @java.lang.SuppressWarnings( { "ConstantConditions", "deprecation" } )
  public #{entity.jpa.name}(#{immutable_attributes.collect{|a| "#{nullable_annotate(a, "final #{a.jpa.java_type}", false)} #{a.jpa.field_name}"}.join(', ')})
  {
JAVA
        java += declared_immutable_attributes.collect{|a| "    this.#{a.jpa.field_name} = #{!a.nullable? && !a.jpa.primitive? ? "java.util.Objects.requireNonNull( #{a.jpa.field_name} )": a.jpa.field_name};\n" }.join('')
        java += declared_immutable_attributes.select{|a|a.reference? && a.inverse.jpa.java_traversable?}.collect{|a| '    ' + j_add_to_inverse(a) + "\n" }.join('')
        java = java + <<JAVA
  }
JAVA
        java
      end

      def j_declared_attribute_accessors(entity)
        entity.declared_attributes.select{|attribute| attribute.jpa? && attribute.jpa.persistent? }.collect do |attribute|
          if attribute.abstract?
            j_abstract_attribute(attribute)
          elsif attribute.reference?
            j_reference_attribute(attribute)
          else
            j_simple_attribute(attribute)
          end
        end.compact.join("")
      end

      def j_declared_attribute_and_relation_accessors(entity)
        relation_methods = entity.referencing_attributes.collect do |attribute|
          if attribute.abstract? || attribute.inherited? || !attribute.entity.jpa? || !attribute.jpa.persistent? || !attribute.inverse.jpa.java_traversable? || attribute.referenced_entity != entity
            # Ignore abstract attributes as will appear in child classes
            # Ignore inherited attributes as appear in parent class
            # Ignore attributes that have no inverse relationship
            nil
          elsif attribute.inverse.multiplicity == :many
            j_has_many_attribute(attribute)
          else #attribute.inverse.multiplicity == :one || attribute.inverse.multiplicity == :zero_or_one
            name = attribute.inverse.name
            field_name = Reality::Naming.camelize( name )

            java = <<JAVA
  #{nullable_annotate(attribute, "public #{attribute.entity.jpa.qualified_name}", false, true)} #{getter_for(attribute, name)}
  {
    #{attribute.primary_key? ? '' :'verifyNotRemoved();'}
    return #{field_name};
  }

  #{j_deprecation_warning(attribute)}final void add#{name}( #{nullable_annotate(attribute, "final #{attribute.entity.jpa.qualified_name}", false, true)} value )
  {
    #{attribute.primary_key? ? '' :'verifyNotRemoved();'}
    if( null != this.#{field_name} )
    {
      throw new IllegalStateException("Attempted to add value when non null value exists.");
    }
    if( value != this.#{field_name} )
    {
      this.#{field_name} = value;
    }
  }

  public final void remove#{name}( #{nullable_annotate(attribute, "final #{attribute.entity.jpa.qualified_name}", false, true)} value )
  {
    #{attribute.primary_key? ? '' :'verifyNotRemoved();'}
    if( null != this.#{field_name} && value != this.#{field_name} )
    {
      throw new IllegalStateException("Attempted to remove value that was not the same.");
    }
    if( null != this.#{field_name} )
    {
      this.#{field_name} = null;
    }
  }

JAVA
            java
          end
        end
        j_declared_attribute_accessors(entity) + relation_methods.compact.join("\n")
      end

      def j_return_if_value_same(attribute, field_name, primitive, nullable)
        accessor = "this.#{field_name}"
        if attribute.entity.jpa.track_changes? && attribute.jpa.fetch_type == :lazy
          accessor = "doGet#{attribute.name}()"
        end
        if primitive
          return <<JAVA
     if( #{accessor} == value )
     {
       return;
     }
JAVA
        elsif !nullable
          return <<JAVA
     //noinspection ConstantConditions
     if( null == value )
     {
       throw new NullPointerException( "#{field_name} parameter is not nullable" );
     }

     if( value.equals( #{accessor} ) )
     {
       return;
     }
JAVA
        else
          return <<JAVA
     if( null != #{accessor} && #{accessor}.equals( value ) )
     {
       return;
     }
     else if( null != value && value.equals( #{accessor} ) )
     {
       return;
     }
     else if( null == #{accessor} && null == value )
     {
       return;
     }
JAVA
        end
      end

      def j_simple_attribute(attribute)
        name = attribute.jpa.name
        java = <<JAVA
  #{annotated_type(attribute, :jpa, :default, :assume_generated => true, :public => true)} #{getter_for(attribute)}
  {
JAVA
        unless attribute.primary_key?
          java << <<JAVA
    verifyNotRemoved();
JAVA
        end
        if attribute.generated_value? && !attribute.nullable?
          java << <<JAVA
    if( null == this.#{attribute.jpa.field_name} )
    {
      throw new IllegalStateException("Attempting to access generated value #{name} before it has been flushed to the database.");
    }
JAVA
        end
        if attribute.entity.jpa.track_changes? && attribute.jpa.fetch_type == :lazy && !attribute.immutable?
          java << <<JAVA
    #{annotated_type(attribute, :jpa, :default, :final => true)} value = doGet#{name}();
    if( !#{attribute.jpa.field_name}Recorded )
    {
      #{attribute.jpa.field_name}Original = #{attribute.jpa.field_name};
      #{attribute.jpa.field_name}Recorded = true;
    }
    return value;
JAVA
        else
          java << <<JAVA
    return doGet#{name}();
JAVA
        end
        java << <<JAVA
  }

  @SuppressWarnings( "ConstantValue" )
  #{annotated_type(attribute, :jpa, :default, :protected => true)} doGet#{name}()
  {
JAVA
        if jpa_nullable_annotation?(attribute) && !jpa_nullable?(attribute)
          java << <<JAVA
    if( null == #{attribute.jpa.field_name} )
    {
      throw new IllegalStateException("Attempting to access non-null field #{name} before it has been set.");
    }
JAVA
        end
        java << <<JAVA
    return #{attribute.jpa.field_name};
  }

JAVA
        if attribute.updatable? || (attribute.generated_value? && :identity != attribute.sql.generator_type)
          java << <<JAVA
  #{attribute.entity.jpa.module_local_mutators? ? '' : 'public '}void set#{name}( #{annotated_type(attribute, :jpa, :default, :final => true)} value )
  {
JAVA
          if jpa_nullable_annotation?(attribute) && !jpa_nullable?(attribute)
            java << "    this.#{attribute.jpa.field_name} = java.util.Objects.requireNonNull( value );\n"
          else
            java << "    this.#{attribute.jpa.field_name} = value;\n"
          end
          java << <<JAVA
  }

JAVA
        end
        java
      end

      def j_add_to_inverse(attribute)
        field_name = attribute.jpa.field_name
        inverse_name = attribute.inverse.name
        unless attribute.inverse.jpa.java_traversable?
          ''
        else
          null_guard(attribute.nullable?, field_name) { "this.#{field_name}.add#{inverse_name}( this );" }
        end
      end

      def j_remove_from_inverse(attribute)
        field_name = attribute.jpa.field_name
        inverse_name = attribute.inverse.name
        if !attribute.inverse.jpa.java_traversable?
          ''
        else
          null_guard(true, field_name) { "#{field_name}.remove#{inverse_name}( this );" }
        end
      end

      def j_reference_attribute(attribute)
        java = <<JAVA
  #{nullable_annotate(attribute, "public #{attribute.jpa.java_type}", false)} #{getter_for(attribute)}
  {
    #{attribute.primary_key? ? '' :'verifyNotRemoved();'}
    return doGet#{attribute.jpa.name}();
  }

  #{nullable_annotate(attribute, "protected #{attribute.jpa.java_type}", false)} doGet#{attribute.jpa.name}()
  {
JAVA
        if attribute.entity.jpa.track_changes? && attribute.jpa.fetch_type == :lazy && !attribute.immutable?
          java << <<JAVA
     if( !#{attribute.jpa.field_name}Recorded )
     {
       #{attribute.jpa.field_name}Original = #{attribute.jpa.field_name};
       #{attribute.jpa.field_name}Recorded = true;
     }
     return #{attribute.jpa.field_name};
JAVA
        else
          java << <<JAVA
    return #{attribute.jpa.field_name};
JAVA
        end
          java << <<JAVA
  }

JAVA
        if attribute.updatable?
          java << <<JAVA
  @java.lang.SuppressWarnings( { "deprecation" } )
  #{attribute.entity.jpa.module_local_mutators? ? '' : 'public '}void set#{attribute.jpa.name}( #{nullable_annotate(attribute, "final #{attribute.jpa.java_type}", false)} value )
  {
 #{j_return_if_value_same(attribute, attribute.jpa.field_name, attribute.referenced_entity.primary_key.jpa.primitive?, attribute.nullable?)}
        #{j_remove_from_inverse(attribute)}
        this.#{attribute.jpa.field_name} = value;
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
   *
   * @deprecated This method should not be called directly. It is called from the constructor of #{attribute.entity.jpa.qualified_name}.
   */
  @java.lang.Deprecated public
STR
        else
          ''
        end
      end

      def j_has_many_attribute(attribute)
        name = attribute.inverse.name
        plural_name = Reality::Naming.pluralize(name)
        field_name = Reality::Naming.camelize(plural_name)
        type = attribute.entity.jpa.qualified_name
        java = <<STR
  public java.util.List<#{type}> get#{plural_name}()
  {
    verifyNotRemoved();
    return java.util.Collections.unmodifiableList( safeGet#{plural_name}() );
  }

  #{j_deprecation_warning(attribute)}final void add#{name}( @javax.annotation.Nonnull final #{type} value )
  {
    final var #{field_name}Safe = safeGet#{plural_name}();
    if ( !#{field_name}Safe.contains( value ) )
    {
      #{field_name}Safe.add( value );
    }
  }

  public final void remove#{name}( @javax.annotation.Nonnull final #{type} value )
  {
    if ( null != this.#{field_name} )
    {
      this.#{field_name}.remove( value );
    }
  }

  @javax.annotation.Nonnull
  private java.util.List<#{type}> safeGet#{plural_name}()
  {
    if( null == this.#{field_name} )
    {
      this.#{field_name} = new java.util.LinkedList<>();
    }
    return this.#{field_name};
  }

STR
        java
      end

      def j_equals_method(entity)
        return '' if entity.abstract?
        pk = entity.primary_key
        pk_getter = "doGet#{entity.primary_key.jpa.name}()"
        pk_type = nullable_annotate(pk, pk.jpa.java_type, false)
        equality_comparison = (!pk.jpa.primitive?) ? "java.util.Objects.equals( #{pk_getter}, that.#{pk_getter} )" : "#{pk_getter} == that.#{pk_getter}"
        s = <<JAVA
  @java.lang.SuppressWarnings( "ConstantValue" )
  @java.lang.Override
  public boolean equals( final Object o )
  {
    if ( this == o )
    {
      return true;
    }
    else if ( !(o instanceof #{entity.jpa.name} that) )
    {
      return false;
    }
    else
    {
      return #{equality_comparison};
    }
  }

  @java.lang.Override
  @java.lang.SuppressWarnings( "ConstantValue" )
  public int hashCode()
  {
    final var key = #{pk_getter};
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
  @java.lang.Override
  public String toString()
  {
    return "#{entity.name}[" +
JAVA
        s += entity.attributes.select{|a| a.jpa? && a.jpa.persistent?}.collect do |a|
          "           \"#{a.jpa.name} = \" + doGet#{a.jpa.name}()"
        end.join(" + \", \" +\n")
        s += <<JAVA
 +
           "]";
  }

JAVA
        s
      end

      def jpa_nullable_annotation?(attribute)
        # Not sure why PrimaryKeys can not have annotation other than the fact that EclipseLink fails
        # to find ID if it is
        !attribute.jpa.primitive? && !attribute.primary_key?
      end

      def jpa_nullable?(attribute, inverse_side = false)
        (!inverse_side && (attribute.nullable? || attribute.generated_value?)) ||
          (attribute.reference? && attribute.inverse.multiplicity == :zero_or_one && inverse_side)
      end

      def nullable_annotate(attribute, type, is_field_annotation, inverse_side = false)
        if !jpa_nullable_annotation?(attribute)
          return type
        else
          annotation = "#{nullability_annotation(jpa_nullable?(attribute, inverse_side))} #{type}"
        end
        if is_field_annotation
          "  #{annotation}\n"
        else
          annotation
        end
      end

      def query_component_result_type(query, maybe_primitive)
        query.result_entity? ?
          query.entity.jpa.qualified_name :
          query.result_struct? ?
            query.struct.ee.qualified_name :
            maybe_primitive && Domgen::TypeDB.characteristic_type_by_name(query.result_type).java.primitive_type? ?
            Domgen::TypeDB.characteristic_type_by_name(query.result_type).java.primitive_type :
            Domgen::TypeDB.characteristic_type_by_name(query.result_type).java.object_type
      end

      def query_result_type(query, qualifier)
        return "#{qualifier}void" if query.query_type == :update && !query.result_type?
        return "#{qualifier}boolean" if query.query_type == :update && query.result_type == :boolean
        return "#{qualifier}int" if query.query_type != :select
        try_primitive = query.multiplicity == :one
        name = query_component_result_type(query, try_primitive)
        return "#{nullability_annotation(false)} #{qualifier}java.util.List<#{name}>" if query.multiplicity == :many
        is_primitive = try_primitive && query.multiplicity == :one && !query.result_entity? && !query.result_struct? && Domgen::TypeDB.characteristic_type_by_name(query.result_type).java.primitive_type?
        is_primitive ? "#{qualifier}#{name}" : "#{nullability_annotation(query.multiplicity == :zero_or_one)} #{qualifier}#{name}"
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

      def validation_name(constraint_name)
        "Validate#{constraint_name}"
      end

      def jpa_validation_in_jpa?(constraint)
        entity = constraint.entity
        if constraint.is_a?(CodependentConstraint) || constraint.is_a?(XorConstraint) || constraint.is_a?(IncompatibleConstraint)
          return constraint.attribute_names.all? { |attribute_name| a = entity.attribute_by_name(attribute_name); a.jpa? && a.jpa.persistent? }
        elsif constraint.is_a?(RelationshipConstraint)
          lhs = entity.attribute_by_name(constraint.lhs_operand)
          rhs = entity.attribute_by_name(constraint.rhs_operand)
          return lhs.jpa? && lhs.jpa.persistent? && rhs.jpa? && rhs.jpa.persistent?
        elsif constraint.is_a?(CycleConstraint)
          target_attribute = entity.attribute_by_name(constraint.attribute_name)
          scoping_attribute = target_attribute.referenced_entity.attribute_by_name(constraint.scoping_attribute)

          current_entity = entity
          elements = constraint.attribute_name_path.collect do |element_name|
            new_attr = current_entity.attribute_by_name(element_name)
            current_entity = new_attr.referenced_entity
            new_attr
          end + [target_attribute, scoping_attribute]
          return elements.all? { |attribute| attribute.jpa? && attribute.jpa.persistent? }
        elsif constraint.is_a?(DependencyConstraint)
          target_attribute = entity.attribute_by_name(constraint.attribute_name)

          return target_attribute.jpa? &&
            constraint.dependent_attribute_names.all? { |attribute_name| a = entity.attribute_by_name(attribute_name); a.jpa? && a.jpa.persistent? }
        else
          return false
        end
      end

      def validation_prefix(constraint_name, entity)
        return <<JAVA
  @java.lang.annotation.Target( { java.lang.annotation.ElementType.TYPE } )
  @java.lang.annotation.Retention( java.lang.annotation.RetentionPolicy.RUNTIME )
  @javax.validation.Constraint( validatedBy = #{constraint_name}Validator.class )
  @java.lang.annotation.Documented
  public @interface #{validation_name(constraint_name)}
  {
    String message() default "{#{entity.jpa.qualified_name}.#{constraint_name}}";

    Class<?>[] groups() default { };

    Class<? extends javax.validation.Payload>[] payload() default { };
  }

  public static class #{constraint_name}Validator
    implements javax.validation.ConstraintValidator<#{validation_name(constraint_name)}, #{entity.jpa.name}>
  {
    @java.lang.Override
    public boolean isValid( final #{entity.jpa.name} object, final javax.validation.ConstraintValidatorContext constraintContext )
    {
      if ( null == object )
      {
        return true;
      }
      try
      {
JAVA
      end

      def validation_suffix
        return <<JAVA
      }
      catch( final Throwable t )
      {
        return false;
      }
      return true;
    }
  }
JAVA
      end
    end
  end
end
