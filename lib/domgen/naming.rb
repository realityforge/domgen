module Domgen
  module Naming
    def self.camelize(string)
      return string if string =~ /^[A-Z0-9_]+$/
      string[0...1].downcase + string[1..100000]
    end
  end
end