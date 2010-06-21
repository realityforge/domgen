# banner in sql generation
def banner(title)
  <<SQL
--
-- #{title}
--
SQL
end

# clean up string so it can be a sql identifier
def s(string)
  string.to_s.gsub('[].:', '')
end

# quote string using database rules
def q(string)
  "[#{string.to_s}]"
end

SQL_PREFIX_MAP = {:table => 'tbl', :trigger => 'trg'}

def sql_name(type, name)
  "#{SQL_PREFIX_MAP[type]}#{name}"
end

def sql_qualify(schema, name)
  "#{q(schema.sql.schema)}.#{q(name)}"
end

def quote_value(value)
  if value.is_a? TrueClass
    '1'
  elsif value.is_a? FalseClass
    '0'
  elsif value.is_a? String
    "'#{value}'"
  elsif value.is_a? Numeric
    "(#{value})"
  end
end