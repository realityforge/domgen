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
  FacetManager.facet(:timerstatus) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :blocking_filter, :filter, :server, :timerstatus, '#{repository.name}TimerAppBlockingFilter'
      java_artifact :integration_test, :rest, :server, :timerstatus, '#{repository.name}TimerstatusTest'

      def additional_timers
        @additional_timers ||= []
      end

      def timers
        timers = []
        repository.data_modules.select{|data_module| data_module.ejb?}.each do |data_module|
          data_module.services.select{|service| service.ejb?}.each do |service|
            service.methods.select{|method|method.ejb? && method.ejb.schedule?}.each do |method|
              timers << method.ejb.schedule.info
            end
          end
        end
        timers + additional_timers
      end

      def pre_complete
        repository.jaxrs.extensions << 'iris.timerstatus.server.service.TimerStatusService' if repository.jaxrs?
      end
    end
  end
end
