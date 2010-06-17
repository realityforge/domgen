require 'erb'
require 'fileutils'
require 'logger'

require "#{File.dirname(__FILE__)}/orderedhash.rb"

# Core components
require "#{File.dirname(__FILE__)}/model.rb"
require "#{File.dirname(__FILE__)}/template.rb"
require "#{File.dirname(__FILE__)}/render_context.rb"
require "#{File.dirname(__FILE__)}/generator.rb"
require "#{File.dirname(__FILE__)}/helper.rb"

# Java
require "#{File.dirname(__FILE__)}/java/model.rb"

# Ruby
require "#{File.dirname(__FILE__)}/ruby/model.rb"

# SQL
require "#{File.dirname(__FILE__)}/sql/model.rb"
require "#{File.dirname(__FILE__)}/sql/helper.rb"
require "#{File.dirname(__FILE__)}/sql/generator.rb"

# JPA
require "#{File.dirname(__FILE__)}/jpa/model.rb"
require "#{File.dirname(__FILE__)}/jpa/helper.rb"
require "#{File.dirname(__FILE__)}/jpa/generator.rb"

# ActiveRecord
require "#{File.dirname(__FILE__)}/active_record/generator.rb"
