module Domgen
  module Xml
    module Helper
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

      def format_text(text)
        p = Pushdown.new
        text.lines.each do |line|
          p.add_line(line)
        end
        p.write(doc)
      end

      class Pushdown
        ITEM = "listitem"
        LIST = "itemizedlist"
        PARA = "para"

        def initialize
          @levels = [[]]
          @blank = false
          push(PARA, 0)
        end

        def write(doc)
          @levels[0].each do |lazy_tag|
            lazy_tag.to_tag(doc)
          end
        end

        def add_line(line)
          if line.gsub(/\s/, '').empty?
            # blank - end of paragraph
            @blank = true
          else
            indent = indent_of(line)
            while @levels.size > 1 && indent < @levels[-1].level
              pop
            end

            if leading(line) == "*"
              if @levels[-1].name == ITEM
                # new listitem in an existing list
                pop; push(ITEM, indent); push(PARA, indent + 2)
              else
                # new list
                pop; push(LIST, indent); push(ITEM, indent); push(PARA, indent + 2)
              end
            elsif @levels[-1].name == ITEM
              # close list item and list and open a paragraph
              pop; pop; push(PARA, indent)
            elsif @blank
              # new paragraph
              pop; push(PARA, indent)
            end
            @levels[-1] << Text.new(line.gsub(/^\s*(\* )?/, ''))
            @blank = false
          end
        end

        private

        def indent_of(line)
          m = /^\s+/.match(line)
          m.nil? ? 0 : m[0].size
        end

        def leading(line)
          line.sub(/\s*/, '')[0..0]
        end

        def pop
          @levels.pop unless 1 == @levels.size
        end

        def push(name, level)
          tag = LazyTag.new(name, level)
          @levels << tag
          @levels[-2] << tag
        end
      end

      class LazyTag
        attr_accessor :level
        attr_accessor :name

        def initialize(name, level)
          @name = name
          @level = level
          @children = []
        end

        def to_tag(doc)
          doc.tag!(@name) do
            @children.each { |child| child.to_tag(doc) }
          end
        end

        def <<(child)
          @children << child
        end
      end

      class Text
        def initialize(text)
          @text = text
        end

        def to_tag(doc)
          doc.text! @text
        end
      end

    end
  end
end

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