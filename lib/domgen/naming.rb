module Domgen
  module Naming
    def self.camelize(lower_case_and_underscored_word, first_letter_in_uppercase = false)
      if first_letter_in_uppercase
        lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
      else
        lower_case_and_underscored_word.to_s[0].chr.downcase + camelize(lower_case_and_underscored_word, true)[1..-1]
      end
    end

    def self.underscore(camel_cased_word)
      word = camel_cased_word.to_s.dup
      word.gsub!(/::/, '/')
      word.gsub!(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
      word.tr!("-", "_")
      word.downcase!
      word
    end

    def self.uppercase_constantize(camel_cased_word)
      underscore(camel_cased_word).upcase
    end

    def self.xmlize(camel_cased_word)
      underscore(camel_cased_word).tr("_", "-")
    end

    def self.pluralize(string)
      plural = nil
      #in case someone passes in a Symbol instead
      singular = string.to_s
      case last(singular)
        when 'y'
          plural = "#{singular.chop}ies" unless last(singular.chop) =~ /[aeiou]/
        when 'o'
          plural = "#{singular}es" if last(singular.chop) =~ /[aeiou]/
        when 's'
          plural = "#{singular}es" if last(singular, 2) == 'ss'
      end
      plural || "#{singular}s"
    end

    private

    def self.last(s, limit = 1)
      return s if limit > s.to_s.size
      s.to_s[-limit, limit]
    end
  end
end