module Domgen
  module Naming
    def self.camelize(string)
      string[0...1].downcase + string[1..100000]
    end
  end
end