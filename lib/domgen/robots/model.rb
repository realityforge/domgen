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
  module Robots
    class UserAgent < Domgen.ParentedElement(:robots_repository)
      attr_reader :name

      def initialize(robots_repository, name, options = {}, &block)
        @name = name
        robots_repository.send(:register_user_agent, self)
        super(robots_repository, options, &block)
      end

      def disallows
        @disallows ||= []
      end

      def disallow(path)
        self.disallows << path
      end
    end
  end

  FacetManager.facet(:robots) do |facet|
    facet.enhance(Repository) do
      def user_agent(name, options = {}, &block)
        Domgen::Robots::UserAgent.new(self, name, options, &block)
      end

      def user_agent_by_name?(name)
        user_agent_map[name.to_s]
      end

      def user_agent_by_name(name)
        user_agent = user_agent_map[name.to_s]
        Domgen.error("Unable to locate user agent #{name}") unless user_agent
        user_agent
      end

      def user_agents?
        user_agent_map.size > 0
      end

      def user_agents
        user_agent_map.values
      end

      attr_writer :generate_robots

      def generate_robots?
        @generate_robots || (!repository.application? || repository.application.code_deployable?)
      end

      def pre_complete
        unless user_agents?
          user_agent('*') do |a|
            a.disallow('/')
          end
        end
      end

      protected

      def register_user_agent(user_agent)
        Domgen.error("Attempting to redefine user agent '#{user_agent.name}'") if user_agent_map[user_agent.name.to_s]
        user_agent_map[user_agent.name.to_s] = user_agent
      end

      def user_agent_map
        @user_agents ||= Domgen::OrderedHash.new
      end
    end
  end
end
