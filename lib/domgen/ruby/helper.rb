module Domgen
  module Ruby
    module Helper
      def ruby_name(s)
        s.gsub(/[:\-\/\\ ]/, '_')
      end
    end
  end
end