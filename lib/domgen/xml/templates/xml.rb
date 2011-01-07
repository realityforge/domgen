module Domgen::Xml
  module Templates
  module Xml
    def generate
      @doc = Builder::XmlMarkup.new(:indent => 2)
      visit_data_module(@data_module)
    end

    attr_reader :doc

    def visit_data_module(dm)
      doc.tag!("data-module", :name => dm.name) do
        dm.object_types.each do |object_type|
          visit_object_type(object_type)
        end
        add_tags(dm)
      end
    end

    def visit_object_type(object_type)
      doc.tag!("object-type", collect_attributes(object_type, %w(name qualified_name))) do
        tag_each(object_type, :attributes) do |attribute|
          visit_attribute(attribute)
        end

        %w(unique codependent incompatible).each do |constraint_type|
          tag_each(object_type, "#{constraint_type}_constraints".to_sym) do |constraint|
            doc.tag!("#{constraint_type}-constraint") do
              constraint.attribute_names.each do |name|
                attribute_ref(object_type, name)
              end
            end
          end
        end

        tag_each(object_type, :dependency_constraints) do |constraint|
          doc.tag!("dependency-constraint") do
            attribute_ref(object_type, constraint.attribute_name)
            doc.tag!("dependent-attributes") do
              constraint.dependent_attribute_names.each do |name|
                attribute_ref(object_type, name)
              end
            end
          end
        end

        tag_each(object_type, :cycle_constraints) do |constraint|
          doc.tag!("cycle-constraint") do
            attribute_ref(object_type, constraint.attribute_name)
            doc.tag!("path") do
              constraint.attribute_name_path.reduce object_type do |path_object_type, attribute_name|
                attribute_ref(path_object_type, attribute_name)
                path_object_type.attribute_by_name(attribute_name).referenced_object
              end
            end
            doc.tag!("scoping-attribute") do
              attribute_ref(object_type, constraint.scoping_attribute)
            end
          end
        end

        visit_table(object_type.sql)

        add_tags(object_type)
      end
    end

    def visit_attribute(attribute)
      attribute_names = %w(abstract? override? reference? validate? set_once? generated_value?
                           enum? primary_key? allow_blank? unique? nullable? immutable? persistent?
                           updatable? allow_blank? qualified_name length min_length name)
      doc.attribute({"object-type" => attribute.object_type.qualified_name},
                    collect_attributes(attribute, attribute_names)) do
        add_tags(attribute)

        unless attribute.values.nil?
          doc.values do
            attribute.values.each_pair do |name, value|
              doc.value(:code => name, :value => value)
            end
          end
        end

        if attribute.reference?
          doc.reference("references" => attribute.references,
                        "referenced-object" => attribute.referenced_object.qualified_name,
                        "polymorphic" => attribute.polymorphic?.to_s,
                        "link-name" => attribute.referencing_link_name,
                        "inverse-multiplicity" => attribute.inverse_multiplicity.to_s,
                        "inverse-traversable" => attribute.inverse_traversable?.to_s,
                        "inverse-relationship" => attribute.inverse_relationship_name.to_s)
        end

        if attribute.persistent?
          doc.persistent(collect_attributes(attribute.sql, %w(column_name sql_type identity? sparse?
                                                              calculation)))
        end

      end
    end

    def visit_table(table)
      table_attributes = %w(table_name qualified_table_name)
      doc.table(collect_attributes(table, table_attributes)) do
        constraint_attributes = %w(name constraint_name qualified_constraint_name invariant?)
        tag_each(table, :constraints) do |constraint|
          doc.tag!("sql-constraint", collect_attributes(constraint, constraint_attributes))
        end

        tag_each(table, :function_constraints) do |constraint|
          doc.tag!("function-constraint",
                   collect_attributes(constraint, constraint_attributes)) do
            tag_each(constraint, :parameters) do |parameter|
              doc.parameter(:name => parameter)
            end
          end
        end

        tag_each(table, :validations) do |validation|
          doc.validation(:name => validation.name)
        end

        tag_each(table, :triggers) do |trigger|
          doc.trigger(collect_attributes(trigger, %w(name qualified_trigger_name))) do
            tag_each(trigger, :after) do |after|
              doc.after(:condition => after)
            end
            tag_each(trigger, :instead_of) do |instead_of|
              doc.tag!("instead-of", :condition => instead_of)
            end
          end
        end

        index_attributes = %w(filter name cluster? unique?)
        tag_each(table, :indexes) do |index|
          doc.index(collect_attributes(index, index_attributes)) do
            tag_each(index, :attribute_names) do |attribute|
              doc.column(:name => attribute)
            end

            tag_each(index, :include_attribute_names) do |attribute|
              doc.column(:name => attribute)
            end
          end
        end

        key_attributes = %w(name referenced_object_type_name on_update on_delete
                            invariant? constraint_name)
        tag_each(table, :foreign_keys) do |key|
          doc.tag!("foreign-key", {:table => table.table_name}, collect_attributes(key, key_attributes)) do
            doc.tag!("referencing-columns") do
              key.attribute_names.zip(key.referenced_attribute_names) do |attribute, referenced|
                doc.column(:from => attribute, :to => referenced)
              end
            end
          end
        end
        
      end
    end

    def add_tags(item)
      unless item.tags.empty?
        doc.tag!("tags") do
          item.tags.each_pair do |tag, value|
            doc.tag!(tag) { format_text(value) }
          end
        end
      end
    end

    def attribute_ref(object_type, name)
      doc.attribute(:class => object_type.qualified_name, :attribute => name)
    end

  end
  end
end