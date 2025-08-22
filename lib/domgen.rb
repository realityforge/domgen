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
require 'json'
require 'digest/md5'

require 'reality/core'
require 'reality/facets'
require 'reality/generators'
require 'reality/naming'
require 'reality/mash'

# Core components
require 'domgen/core'
require 'domgen/typedb'
require 'domgen/features'
require 'domgen/model'
require 'domgen/facets'
require 'domgen/model_checks'
require 'domgen/template'
require 'domgen/filters'

 # Integration utilities
require 'domgen/util'
require 'domgen/zip_util'
require 'domgen/buildr_integration'

# Json
require 'domgen/json/model'

# Xml
require 'domgen/xml/model'
require 'domgen/xml/helper'

# Java
require 'domgen/java/model'
require 'domgen/java/helper'

require 'domgen/transaction_time/model'

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

# Jackson (JSon deserialization)
require 'domgen/jackson/model'
require 'domgen/jackson/helper'
require 'domgen/jackson/generator'

# JPA
require 'domgen/jpa/model'
require 'domgen/jpa/helper'
require 'domgen/jpa/generator'

# JMS
require 'domgen/jms/model'
require 'domgen/jms/generator'

# Docbook
require 'domgen/xml/generator'

# Rake Tasks
require 'domgen/rake_tasks'

# Rake Task for generating XMI
require 'domgen/xmi_generator'

# EJB
require 'domgen/ejb/model'
require 'domgen/ejb/generator'

# JaxRS
require 'domgen/jaxrs/model'
require 'domgen/jaxrs/helper'
require 'domgen/jaxrs/generator'

# EE
require 'domgen/ee/model'
require 'domgen/ee/generator'

# CE (Client edition ... stuff shared between gwt and ee client side applications)
require 'domgen/ce/model'
require 'domgen/ce/generator'

# GWT
require 'domgen/gwt/model'
require 'domgen/gwt/helper'
require 'domgen/gwt/generator'

# Imit
require 'domgen/imit/model'
require 'domgen/imit/helper'
require 'domgen/imit/generator'

# Database level auditing
require 'domgen/audit/model'
require 'domgen/audit/generator'

# Some caching for gwt apps
require 'domgen/gwt_cache_filter/model'

# Keycloak authentication integration
require 'domgen/keycloak/model'
require 'domgen/keycloak/generator'

require 'domgen/appconfig/model'
require 'domgen/appconfig/generator'

require 'domgen/syncrecord/model'
require 'domgen/syncrecord/generator'

require 'domgen/application/model'

require 'domgen/robots/model'
require 'domgen/robots/generator'

require 'domgen/redfish/model'
require 'domgen/redfish/generator'

require 'domgen/arez/model'
require 'domgen/arez/helper'
require 'domgen/arez/generator'

require 'domgen/sql_analysis/model'
require 'domgen/sql_analysis/generator'

require 'domgen/react4j/model'

require 'domgen/serviceworker/model'

require 'domgen/action/model'
require 'domgen/action/generator'
