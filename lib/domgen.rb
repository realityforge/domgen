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

require_relative 'domgen/base_element'
require_relative 'domgen/logging'
require_relative 'domgen/options'
require_relative 'domgen/naming'

require_relative 'domgen/generators/render_context'
require_relative 'domgen/generators/target_manager'
require_relative 'domgen/generators/template'
require_relative 'domgen/generators/ruby_template'
require_relative 'domgen/generators/erb_template'
require_relative 'domgen/generators/template_set'
require_relative 'domgen/generators/template_set_container'
require_relative 'domgen/generators/generator'
require_relative 'domgen/generators/standard_template_set'
require_relative 'domgen/generators/standard_artifact_dsl'
require_relative 'domgen/generators/rake_integration'
require_relative 'domgen/generators/runner'

require_relative 'domgen/generators/buildr_integration'

require_relative 'domgen/facets/target_manager'
require_relative 'domgen/facets/extension_manager'
require_relative 'domgen/facets/faceted_model'
require_relative 'domgen/facets/facet'
require_relative 'domgen/facets/facet_container'
require_relative 'domgen/facets/generators_integration'

require_relative 'domgen/mash'

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

# JPA
require 'domgen/jpa/model'
require 'domgen/jpa/helper'
require 'domgen/jpa/generator'

# JMS
require 'domgen/jms/model'
require 'domgen/jms/generator'

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

# Some caching for gwt apps
require 'domgen/gwt_cache_filter/model'

require 'domgen/application/model'

require 'domgen/redfish/model'
require 'domgen/redfish/generator'

require 'domgen/arez/model'
require 'domgen/arez/helper'
require 'domgen/arez/generator'

require 'domgen/sql_analysis/model'
require 'domgen/sql_analysis/generator'

require 'domgen/react4j/model'

require 'domgen/action/model'
require 'domgen/action/generator'
