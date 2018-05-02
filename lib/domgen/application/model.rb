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

module Domgen
  FacetManager.facet(:application) do |facet|
    facet.suggested_facets << :robots

    facet.enhance(Repository) do

      # return true if the model code for repository can be included in separate project as a library
      def model_library?
        @model_library.nil? ? true : !!@model_library
      end

      attr_writer :model_library

      # return true if the service code for repository can be included in separate project as a library.
      # This implies the code is not an independent deployable unit.
      def service_library?
        @service_library.nil? ? false : !!@service_library
      end

      def service_library=(service_library)
        @service_library = service_library
        disable_deployment_facets if service_library
      end

      # return true if the application has a UI to be presented to humans.
      def user_experience?
        !service_library? && @user_experience.nil? ? repository.gwt? : !!@user_experience
      end

      attr_writer :user_experience

      # return true if the database scripts for repository is independently deployable.
      def db_deployable?
        repository.sql? && (@db_deployable.nil? ? code_deployable? : !!@db_deployable)
      end

      attr_writer :db_deployable

      # return true if the code for repository is independently deployable. Must not be a service library.
      def code_deployable?
        !service_library? && (@code_deployable.nil? ? true : !!@code_deployable)
      end

      def code_deployable=(code_deployable)
        @code_deployable = code_deployable
        disable_deployment_facets unless code_deployable
      end

      private

      def disable_deployment_facets
        repository.disable_facet(:robots) if repository.robots?
        repository.disable_facet(:appcache) if repository.appcache?
        repository.disable_facet(:gwt_cache_filter) if repository.gwt_cache_filter?
      end
    end
  end
end
