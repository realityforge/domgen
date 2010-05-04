require 'yaml'
require 'erb'
require 'fileutils'

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

def pluralize(string)
  "#{string}s"
end

def underscore(camel_cased_word)
  camel_cased_word.to_s.gsub(/::/, '/').
          gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').
          gsub(/([a-z\d])([A-Z])/, '\1_\2').
          tr("-", "_").
          downcase
end

def java_accessors(name,type)
  <<JAVA
  public #{type} get#{name}()
  {
     return #{name};
  }

  public void set#{name}( final #{type} value )
  {
     #{name} = value;
  }
JAVA
end

require "#{File.dirname(__FILE__)}/model.rb"
require "#{File.dirname(__FILE__)}/generator.rb"

# Model extensions
require "#{File.dirname(__FILE__)}/java_model_ext.rb"
require "#{File.dirname(__FILE__)}/ruby_model_ext.rb"
require "#{File.dirname(__FILE__)}/sql_model_ext.rb"
require "#{File.dirname(__FILE__)}/jpa_model_ext.rb"

# Generator extensions
require "#{File.dirname(__FILE__)}/jpa_generator_ext.rb"
require "#{File.dirname(__FILE__)}/sql_generator_ext.rb"
require "#{File.dirname(__FILE__)}/active_record_generator_ext.rb"
