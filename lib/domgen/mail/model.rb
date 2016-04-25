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
  FacetManager.facet(:mail => [:ee]) do |facet|
    facet.enhance(Repository) do
      include Domgen::Java::BaseJavaGenerator
      include Domgen::Java::JavaClientServerApplication

      java_artifact :mail_queue, :service, :server, :mail, '#{repository.name}MailQueueServiceImpl'

      attr_writer :resource_name

      def resource_name
        @resource_name || "#{Domgen::Naming.underscore(repository.name)}/mail/session"
      end

      attr_writer :persist_on_send

      def persist_on_send?
        @persist_on_send.nil? ? false : !!@persist_on_send
      end

      attr_writer :clear_message_on_send

      def clear_message_on_send?
        @clear_message_on_send.nil? ? true : !!@clear_message_on_send
      end

      attr_writer :persist_on_error

      def persist_on_error?
        @persist_on_error.nil? ? true : !!@persist_on_error
      end

      attr_writer :clear_error_on_send

      def clear_error_on_send?
        @clear_error_on_send.nil? ? true : !!@clear_error_on_send
      end
    end
  end
end
