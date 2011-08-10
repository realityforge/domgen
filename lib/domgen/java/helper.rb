module Domgen
  module Java
    module Helper
      def description_javadoc_for(element, depth = "  ")
        description = element.tags[:Description]
        return '' unless description
        return <<JAVADOC
#{depth}/**
#{depth} * #{description.gsub(/\n+\Z/,"").gsub("\n\n","\n<br />\n").gsub("\n","\n#{depth} * ")}
#{depth} */
JAVADOC
      end
    end
  end
end
