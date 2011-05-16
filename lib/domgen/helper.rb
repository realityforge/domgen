def pluralize(string)
  plural = nil
  case last(string)
    when 'y'
      plural = "#{string.chop}ies" unless last(string.chop) =~ /[aeiou]/
    when 'o'
      plural = "#{string}es" if last(string.chop) =~ /[aeiou]/
    when 's'
      plural = "#{string}es" if last(string, 2) == 'ss'
  end
  plural = "#{string}s" if plural.nil?
  plural
end

def underscore(camel_cased_word)
  camel_cased_word.to_s.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
    gsub(/([a-z\d])([A-Z])/, '\1_\2').
    tr("-", "_").
    downcase
end

def uppercase_constantize(word)
  underscore(word).upcase
end

private

def last(s, limit = 1)
  return s if limit > s.to_s.size
  s.to_s[-limit, limit]
end
