module Domgen
  module Docbook
    class Helper
      def to_tag_name(name)
        name.to_s.gsub(/_/, '-').gsub(/\?/, '')
      end

      def tag_each(target, name)
        doc.tag!(to_tag_name(name)) do
          target.send(name).each do |item|
            yield item
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

    end
  end
end

class Builder::XmlMarkup
  def _nested_structures(block)
    super(block)
    unless target! =~ /\n$/
      _newline
    end
  end
end