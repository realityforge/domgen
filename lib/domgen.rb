#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'erb'
require 'fileutils'
require 'logger'

require 'domgen/version'
require 'domgen/orderedhash'
require 'domgen/naming'

# Core components
require 'domgen/core'
require 'domgen/facets'
require 'domgen/typedb'
require 'domgen/features'
require 'domgen/model'
require 'domgen/template'
require 'domgen/render_context'
require 'domgen/generator'
require 'domgen/filters'

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

# MsSQL
require 'domgen/mssql/model'
require 'domgen/mssql/helper'
require 'domgen/mssql/generator'

# PgSQL
require 'domgen/pgsql/model'
require 'domgen/pgsql/generator'

# JAXB
require 'domgen/jaxb/model'
require 'domgen/jaxb/helper'
require 'domgen/jaxb/generator'

# Jackson (JSon deserialization)
require 'domgen/jackson/model'
require 'domgen/jackson/helper'

# JPA
require 'domgen/jpa/model'
require 'domgen/jpa/helper'
require 'domgen/jpa/generator'

# JMS
require 'domgen/jms/model'
require 'domgen/jms/generator'

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
require 'domgen/jws/wsimport_template'
require 'domgen/jws/generator'

# JMX
require 'domgen/jmx/model'
require 'domgen/jmx/generator'

# JaxRS
require 'domgen/jaxrs/model'
require 'domgen/jaxrs/helper'
require 'domgen/jaxrs/generator'

# EE
require 'domgen/ee/model'
require 'domgen/ee/generator'

# GWT
require 'domgen/gwt/model'
require 'domgen/gwt/generator'

# GwtRPC
require 'domgen/gwt_rpc/model'
require 'domgen/gwt_rpc/generator'

# RestyGWT
require 'domgen/restygwt/model'
require 'domgen/restygwt/helper'
require 'domgen/restygwt/generator'

# Imit
require 'domgen/imit/model'
require 'domgen/imit/generator'

# AutoBean
require 'domgen/auto_bean/model'
require 'domgen/auto_bean/generator'

# Database level auditing
require 'domgen/audit/model'
require 'domgen/audit/generator'

# Database level synchronization
require 'domgen/sync/model'
require 'domgen/sync/generator'
