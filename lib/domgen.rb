require 'erb'
require 'fileutils'
require 'logger'

require "domgen/orderedhash.rb"

# Core components
require "domgen/model.rb"
require "domgen/template.rb"
require "domgen/render_context.rb"
require "domgen/generator.rb"
require "domgen/helper.rb"

# Java
require "domgen/java/model.rb"

# Ruby
require "domgen/ruby/model.rb"

# SQL
require "domgen/sql/model.rb"
require "domgen/sql/helper.rb"
require "domgen/sql/generator.rb"

# JPA
require "domgen/jpa/model.rb"
require "domgen/jpa/helper.rb"
require "domgen/jpa/generator.rb"

# ActiveRecord
require "domgen/active_record/generator.rb"

require "domgen/rake_tasks.rb"

