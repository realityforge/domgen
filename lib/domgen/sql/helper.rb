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

SQL_PREFIX_MAP = {:table => 'tbl', :trigger => 'trg'}

def sql_name(type, name)
  "#{SQL_PREFIX_MAP[type]}#{name}"
end

module Domgen
  module Ruby
    module MssqlHelper
      # Change tags named Description to MS_Description when making into an extended property as
      # that is the MS standard for documentation properties
      def sql_extended_property_key(name)
        (name.to_s == 'Description') ? 'MS_Description' : name
      end

      def sql_extended_property_value(value)
        Domgen::Sql.dialect.quote_string(value).strip
      end
    end
  end
end