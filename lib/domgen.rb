require 'erb'
require 'fileutils'
require 'logger'

require 'domgen/orderedhash'
require 'domgen/naming'

# Core components
require 'domgen/core'
require 'domgen/facets'
require 'domgen/model'
require 'domgen/template'
require 'domgen/render_context'
require 'domgen/generator'

# Json
require 'domgen/json/model'

# Xml
require 'domgen/xml/model'
require 'domgen/xml/helper'

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

# JAXB
require 'domgen/jaxb/model'
require 'domgen/jaxb/helper'

# Jackson (JSon deserialization)
require 'domgen/jackson/model'
require 'domgen/jackson/helper'

# JPA
require 'domgen/jpa/model'
require 'domgen/jpa/helper'
require 'domgen/jpa/generator'

# ActiveRecord
require 'domgen/active_record/generator'

# Docbook
require 'domgen/xml/templates/xml'
require 'domgen/xml/generator'

# Rake Tasks
require 'domgen/rake_tasks'

# Rake Task for generating XMI
require 'domgen/xmi_generator'

# EJB
require 'domgen/ejb/model'
require 'domgen/ejb/generator'

# JWS
require 'domgen/jws/model'
require 'domgen/jws/generator'

# JMX
require 'domgen/jmx/model'
require 'domgen/jmx/generator'

# EE
require 'domgen/ee/model'
require 'domgen/ee/generator'

# GWT
require 'domgen/gwt/model'
require 'domgen/gwt/generator'

# Imit
require 'domgen/imit/model'
require 'domgen/imit/generator'
