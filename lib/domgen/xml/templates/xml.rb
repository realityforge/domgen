module Builder
  class XmlMarkup
    def _nested_structures(block)
      super(block)
      # if there was no newline after the last item, indentation
      # will be added anyway, which looks pretty wacky
      unless target! =~ /\n$/
        _newline
      end
    end
  end
end

module Domgen
  module Xml
    module Templates
      module Xml
        def generate
          @doc = Builder::XmlMarkup.new(:indent => 2)

          visit_repository(@repository)
        end

        private

        attr_reader :doc

        def visit_repository(repository)
          doc.tag!("repository", :name => repository.name) do
            add_tags(repository)
            repository.data_modules.each do |data_module|
              visit_data_module(data_module)
            end
          end
        end

        def visit_data_module(data_module)
          doc.tag!("data-module", :name => data_module.name) do
            add_tags(data_module)
            data_module.entities.each do |entity|
              visit_entity(entity)
            end
          end
        end

        def visit_entity(entity)
          doc.tag!("entity", collect_attributes(entity, %w(name qualified_name))) do
            add_tags(entity)

            tag_each(entity, :attributes) do |attribute|
              visit_attribute(attribute)
            end

            %w(unique codependent incompatible).each do |constraint_type|
              tag_each(entity, "#{constraint_type}_constraints".to_sym) do |constraint|
                doc.tag!("#{constraint_type}-constraint") do
                  constraint.attribute_names.each do |name|
                    attribute_ref(entity, name)
                  end
                end
              end
            end

            tag_each(entity, :dependency_constraints) do |constraint|
              doc.tag!("dependency-constraint") do
                attribute_ref(entity, constraint.attribute_name)
                doc.tag!("dependent-attributes") do
                  constraint.dependent_attribute_names.each do |name|
                    attribute_ref(entity, name)
                  end
                end
              end
            end

            tag_each(entity, :cycle_constraints) do |constraint|
              doc.tag!("cycle-constraint") do
                attribute_ref(entity, constraint.attribute_name)
                doc.tag!("path") do
                  constraint.attribute_name_path.reduce entity do |path_entity, attribute_name|
                    attribute_ref(path_entity, attribute_name)
                    path_entity.attribute_by_name(attribute_name).referenced_entity
                  end
                end
                doc.tag!("scoping-attribute") do
                  attribute_ref(entity, constraint.scoping_attribute)
                end
              end
            end

            visit_table(entity.sql)
          end
        end

        def visit_attribute(attribute)
          attribute_names = %w(abstract? override? reference? set_once? generated_value?
                           enumeration? primary_key? allow_blank? unique? nullable? immutable?
                           updatable? allow_blank? qualified_name length min_length name)
          doc.attribute({"entity" => attribute.entity.qualified_name},
                        collect_attributes(attribute, attribute_names)) do
            add_tags(attribute)

            unless attribute.enumeration.values.nil?
              doc.values do
                attribute.enumeration.values.each do |name|
                  doc.value(:code => name)
                end
              end
            end

            if attribute.reference?
              doc.reference("referenced-entity" => attribute.referenced_entity.qualified_name,
                            "polymorphic" => attribute.polymorphic?.to_s,
                            "inverse-multiplicity" => attribute.inverse.multiplicity.to_s,
                            "inverse-traversable" => attribute.inverse.traversable?.to_s,
                            "inverse-relationship" => attribute.inverse.name.to_s)
            end

            attributes = collect_attributes(attribute.sql, %w(column_name identity? sparse? calculation))
            attributes['sql-type'] = attribute.sql.sql_type.gsub('[', '').gsub(']', '')
            doc.persistent(attributes)

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

            key_attributes = %w(name constraint_name)
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
              item.tags.each_pair do |key, value|
                doc.tag!(key) do |v|
                  if [:Description].include?(key)
                    text = item.tag_as_html(key)
                    ENTITY_EXPANDSION_MAP.each_pair do |k, v|
                      text = text.gsub("&#{k};", "&#{v};")
                    end
                    v << text
                  else
                    v << value
                  end
                end
              end
            end
          end
        end

        def attribute_ref(entity, name)
          doc.attribute(:class => entity.qualified_name, :attribute => name)
        end

        def to_tag_name(name)
          name.to_s.gsub(/_/, '-').gsub(/\?/, '')
        end

        def tag_each(target, name)
          values = target.send(name)
          unless values.nil? || values.empty?
            doc.tag!(to_tag_name(name)) do
              values.each do |item|
                yield item
              end
            end
          end
        end

        def collect_attributes(target, names)
          attributes = Hash.new
          names.each do |name|
            value = target.send(name.to_sym)
            if value
              attributes[to_tag_name(name)] = value
            end
          end
          attributes
        end

        ENTITY_EXPANDSION_MAP =
          {
            "ldquo" => "#8220",
          }
      end
    end
  end
end
