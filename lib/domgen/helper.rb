def pluralize(string)
  plural = nil
  #in case someone passes in a Symbol instead
  singular = string.to_s
  case last(string)
    when 'y'
      plural = "#{singular.chop}ies" unless last(singular.chop) =~ /[aeiou]/
    when 'o'
      plural = "#{singular}es" if last(singular.chop) =~ /[aeiou]/
    when 's'
      plural = "#{singular}es" if last(singular, 2) == 'ss'
  end
  plural = "#{singular}s" if plural.nil?
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
