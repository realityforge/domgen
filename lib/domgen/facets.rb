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

module Domgen #nodoc

  module FacetManager
    extend Reality::Facets::FacetContainer

    def self.handle_sub_feature?(object, sub_feature_key)
      return object.reference? if :inverse == sub_feature_key && object.is_a?(Attribute)
      return !object.result.nil? if :result == sub_feature_key && object.is_a?(Method)
      true
    end
  end

  FacetManager.target_manager.target(Domgen::Repository, :repository)
  FacetManager.target_manager.target(Domgen::DataModule, :data_module, :repository)
  FacetManager.target_manager.target(Domgen::RemoteEntity, :remote_entity, :data_module)
  FacetManager.target_manager.target(Domgen::RemoteEntityAttribute, :remote_entity_attribute, :remote_entity, :access_method => 'attributes', :inverse_access_method => 'attribute')
  FacetManager.target_manager.target(Domgen::Entity, :entity, :data_module)
  FacetManager.target_manager.target(Domgen::Attribute, :attribute, :entity, :access_method => 'declared_attributes', :inverse_access_method => 'attribute')
  FacetManager.target_manager.target(Domgen::InverseElement, :inverse, :attribute, :access_method => 'inverse')
  FacetManager.target_manager.target(Domgen::DataAccessObject, :dao, :data_module)
  FacetManager.target_manager.target(Domgen::Query, :query, :dao)
  FacetManager.target_manager.target(Domgen::QueryParameter, :query_parameter, :query, :access_method => 'parameters', :inverse_access_method => 'parameter')
  FacetManager.target_manager.target(Domgen::Service, :service, :data_module)
  FacetManager.target_manager.target(Domgen::Method, :method, :service)
  FacetManager.target_manager.target(Domgen::Parameter, :parameter, :method)
  FacetManager.target_manager.target(Domgen::Result, :result, :method, :access_method => 'result')
  FacetManager.target_manager.target(Domgen::Exception, :exception, :data_module)
  FacetManager.target_manager.target(Domgen::ExceptionParameter, :exception_parameter, :exception, :access_method => 'parameters', :inverse_access_method => 'parameter')
  FacetManager.target_manager.target(Domgen::Message, :message, :data_module)
  FacetManager.target_manager.target(Domgen::MessageParameter, :message_parameter, :message, :access_method => 'parameters', :inverse_access_method => 'parameter')
  FacetManager.target_manager.target(Domgen::EnumerationSet, :enumeration, :data_module)
  FacetManager.target_manager.target(Domgen::EnumerationValue, :value, :enumeration)
  FacetManager.target_manager.target(Domgen::Struct, :struct, :data_module)
  FacetManager.target_manager.target(Domgen::StructField, :field, :struct)
end
