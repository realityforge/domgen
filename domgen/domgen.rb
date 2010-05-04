require "#{File.dirname(__FILE__)}/model.rb"
require "#{File.dirname(__FILE__)}/generator.rb"
require "#{File.dirname(__FILE__)}/helper.rb"

# Model extensions
require "#{File.dirname(__FILE__)}/java_model_ext.rb"
require "#{File.dirname(__FILE__)}/ruby_model_ext.rb"
require "#{File.dirname(__FILE__)}/sql_model_ext.rb"
require "#{File.dirname(__FILE__)}/jpa_model_ext.rb"

# Helper extensions
require "#{File.dirname(__FILE__)}/java_helper_ext.rb"
require "#{File.dirname(__FILE__)}/sql_helper_ext.rb"

# Generator extensions
require "#{File.dirname(__FILE__)}/jpa_generator_ext.rb"
require "#{File.dirname(__FILE__)}/sql_generator_ext.rb"
require "#{File.dirname(__FILE__)}/active_record_generator_ext.rb"
