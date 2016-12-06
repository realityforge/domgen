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
require 'builder'

class Builder::XmlMarkup
  def _nested_structures(block)
    super(block)
    # if there was no newline after the last item, indentation
    # will be added anyway, which looks pretty wacky
    unless target! =~ /\n$/
      _newline
    end
  end
end

def generate(repository)
  doc = Builder::XmlMarkup.new(:indent => 2)
  visit_repository(doc, repository)
end

def visit_repository(doc, repository)
  doc.tag!('repository', :name => repository.name) do
    add_tags(doc, repository)
    repository.data_modules.each do |data_module|
      visit_data_module(doc, data_module)
    end
  end
end

def visit_data_module(doc, data_module)
  doc.tag!('data-module', :name => data_module.name) do
    add_tags(doc, data_module)
    data_module.entities.each do |entity|
      visit_entity(doc, entity)
    end
  end
end

def visit_entity(doc, entity)
  doc.tag!('entity', collect_attributes(entity, %w(name qualified_name))) do
    add_tags(doc, entity)

    tag_each(doc, entity, :attributes) do |attribute|
      visit_attribute(doc, attribute)
    end

    %w(unique codependent incompatible).each do |constraint_type|
      tag_each(doc, entity, "#{constraint_type}_constraints".to_sym) do |constraint|
        doc.tag!("#{constraint_type}-constraint") do
          constraint.attribute_names.each do |name|
            attribute_ref(doc, entity, name)
          end
        end
      end
    end

    tag_each(doc, entity, :dependency_constraints) do |constraint|
      doc.tag!('dependency-constraint') do
        attribute_ref(doc, entity, constraint.attribute_name)
        doc.tag!('dependent-attributes') do
          constraint.dependent_attribute_names.each do |name|
            attribute_ref(doc, entity, name)
          end
        end
      end
    end

    tag_each(doc, entity, :cycle_constraints) do |constraint|
      doc.tag!('cycle-constraint') do
        attribute_ref(doc, entity, constraint.attribute_name)
        doc.tag!('path') do
          constraint.attribute_name_path.reduce entity do |path_entity, attribute_name|
            attribute_ref(doc, path_entity, attribute_name)
            path_entity.attribute_by_name(attribute_name).referenced_entity
          end
        end
        doc.tag!('scoping-attribute') do
          attribute_ref(doc, entity, constraint.scoping_attribute)
        end
      end
    end

    visit_table(doc, entity.sql)
  end
end

def visit_attribute(doc, attribute)
  attribute_names = %w(abstract? override? reference? set_once? generated_value?
                           enumeration? primary_key? allow_blank? unique? nullable? immutable?
                           updatable? allow_blank? qualified_name length min_length name)
  doc.attribute({'entity' => attribute.entity.qualified_name},
                collect_attributes(attribute, attribute_names)) do
    add_tags(doc, attribute)

    if attribute.enumeration?
      doc.values do
        attribute.enumeration.values.each do |enumeration|
          doc.value(:code => enumeration.name)
        end
      end
    end

    if attribute.reference?
      doc.reference('referenced-entity' => attribute.referenced_entity.qualified_name,
                    'polymorphic' => attribute.polymorphic?.to_s,
                    'inverse-multiplicity' => attribute.inverse.multiplicity.to_s,
                    'inverse-traversable' => attribute.inverse.traversable?.to_s,
                    'inverse-relationship' => attribute.inverse.name.to_s)
    end

    attributes = collect_attributes(attribute.sql, %w(column_name identity? sparse? calculation))
    attributes['sql-type'] = attribute.sql.sql_type.gsub('[', '').gsub(']', '')
    doc.persistent(attributes)

  end
end

def visit_table(doc, table)
  table_attributes = %w(table_name qualified_table_name)
  doc.table(collect_attributes(table, table_attributes)) do
    constraint_attributes = %w(name constraint_name qualified_constraint_name invariant?)
    tag_each(doc, table, :constraints) do |constraint|
      doc.tag!('sql-constraint', collect_attributes(constraint, constraint_attributes))
    end

    tag_each(doc, table, :function_constraints) do |constraint|
      doc.tag!('function-constraint',
               collect_attributes(constraint, constraint_attributes)) do
        tag_each(doc, constraint, :parameters) do |parameter|
          doc.parameter(:name => parameter)
        end
      end
    end

    tag_each(doc, table, :validations) do |validation|
      doc.validation(:name => validation.name)
    end

    tag_each(doc, table, :triggers) do |trigger|
      doc.trigger(collect_attributes(trigger, %w(name qualified_trigger_name))) do
        tag_each(doc, trigger, :after) do |after|
          doc.after(:condition => after)
        end
        tag_each(doc, trigger, :instead_of) do |instead_of|
          doc.tag!('instead-of', :condition => instead_of)
        end
      end
    end

    index_attributes = %w(filter name cluster? unique?)
    tag_each(doc, table, :indexes) do |index|
      doc.index(collect_attributes(index, index_attributes)) do
        tag_each(doc, index, :attribute_names) do |attribute|
          doc.column(:name => attribute)
        end

        tag_each(doc, index, :include_attribute_names) do |attribute|
          doc.column(:name => attribute)
        end
      end
    end

    key_attributes = %w(name constraint_name)
    tag_each(doc, table, :foreign_keys) do |key|
      doc.tag!('foreign-key', {:table => table.table_name}, collect_attributes(key, key_attributes)) do
        doc.tag!('referencing-columns') do
          key.attribute_names.zip(key.referenced_attribute_names) do |attribute, referenced|
            doc.column(:from => attribute, :to => referenced)
          end
        end
      end
    end

  end
end

def add_tags(doc, item)
  unless item.tags.empty?
    expansion_map = {'ldquo' => '#8220'}

    doc.tag!('tags') do
      item.tags.each_pair do |key, value|
        doc.tag!(key) do |v|
          if [:Description].include?(key)
            text = item.tag_as_html(key)
            expansion_map.each_pair do |k, v|
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

def attribute_ref(doc, entity, name)
  doc.attribute(:class => entity.qualified_name, :attribute => name)
end

def to_tag_name(name)
  name.to_s.gsub(/_/, '-').gsub(/\?/, '')
end

def tag_each(doc, target, name)
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
