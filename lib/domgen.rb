require 'erb'
require 'fileutils'
require 'logger'

require 'domgen/orderedhash'
require 'domgen/naming'

# Core components
require 'domgen/model'
require 'domgen/template'
require 'domgen/render_context'
require 'domgen/generator'
require 'domgen/helper'

# Java
require 'domgen/java/model'
require 'domgen/java/helper'

# Ruby
require 'domgen/ruby/model'
require 'domgen/ruby/helper'

# SQL
require 'domgen/sql/model'
require 'domgen/sql/helper'
require 'domgen/sql/generator'

# JPA
require 'domgen/jpa/model'
require 'domgen/jpa/helper'
require 'domgen/jpa/generator'

# ActiveRecord
require 'domgen/active_record/generator'

# Docbook
require 'domgen/xml/generator'
require 'domgen/xml/templates/xml'
require 'domgen/xml/helper'

# Rake Tasks
require 'domgen/rake_tasks'

# Rake Task for generating XMI
require 'domgen/xmi_generator'

# EJB
require 'domgen/ejb/model'
require 'domgen/ejb/generator'
