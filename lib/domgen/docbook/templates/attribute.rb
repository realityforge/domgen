module Domgen::Docbook
  module Templates
  module Attribute
    def generate
      @doc = Builder::XmlMarkup.new(:indent => 2)
      visit_data_module(@data_module)
    end

    attr_reader :doc

    def visit_data_module(dm)
      doc.tag!("data-module", :name => dm.name) do
        dm.object_types.each do |object_type|
          doc.tag!("object-type", :name => object_type.name) do
            tag_each(object_type, :attributes) do |attribute|
              visit_attribute(attribute)
            end
            add_tags(object_type)
          end
        end
      end
    end

    def visit_attribute(attribute)
      attribute_names = %w(abstract? override? reference? validate? set_once? generated_value?
                           enum? primary_key? allow_blank? unique? nullable? immutable? persistent?
                           updatable? allow_blank? qualified_name length min_length)
      doc.attribute(collect_attributes(attribute, attribute_names)) do
        add_tags(attribute)

        unless attribute.values.nil?
          doc.values do
            attribute.values.each do |value|
              doc.value { doc.text! value }
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

      end
    end

    def add_tags(item)
      unless item.tags.empty?
        doc.tag!("tags") do
          item.tags.each_pair do |tag, value|
            doc.tag!(tag) { doc.text! value }
          end
        end
      end
    end

  end
  end
end