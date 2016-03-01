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
  module JWS
    class WsimportTemplate < Domgen::Generator::Template
      attr_reader :output_package_pattern

      def initialize(template_set, facets, scope, template_key, output_package_pattern, helpers, options = {})
        super(template_set, facets, scope, template_key, helpers, options)
        @output_package_pattern = output_package_pattern
      end

      def output_path
        "main/java/#{output_package_pattern}"
      end

      protected

      def generate!(target_basedir, element_type, element, unprocessed_files)
        object_name = name_for_element(element)
        render_context = create_context(element_type, element)
        context_binding = render_context.context_binding
        begin
          output_package = eval("\"#{self.output_package_pattern}\"", context_binding, "#{self.template_key}#Filename")
          base_dir = File.join(target_basedir, 'main/java')
          FileUtils.mkdir_p base_dir

          wsdl_filename = "#{target_basedir}/main/resources/META-INF/wsdl/#{element.jws.wsdl_name}"
          raise Domgen::Generator::GeneratorError.new("Missing wsdl #{wsdl_filename} generating #{self.name} for #{element_type} #{object_name}") unless File.exist?(wsdl_filename)

          digest = Digest::MD5.hexdigest(IO.read(wsdl_filename))
          output_dir = "#{base_dir}/#{output_package.gsub('.', '/')}"
          digest_filename = "#{output_dir}/#{element.name}.wsdl.md5"
          unprocessed_files.delete_if{|f| f =~ /^#{output_dir}\/.*/ }
          unprocessed_files.delete(output_dir)

          FileUtils.mkdir_p File.dirname(digest_filename) unless File.directory?(File.dirname(digest_filename))
          if File.exist?(digest_filename) && IO.read(digest_filename) == digest
            Logger.debug "Skipped generation of #{self.name} for #{element_type} #{object_name} to #{output_package} as no changes to wsdl"
          else
            target_version = '7' == element.data_module.repository.ee.version ? '2.2' : '2.1'
            wsdl2java(base_dir, element.jws.web_service_name, output_package, target_version, wsdl_filename, element.jws.system_id)

            File.open(digest_filename, 'w') { |f| f.write(digest) }
            Logger.debug "Generated #{self.name} for #{element_type} #{object_name} to #{output_package}"
          end
        rescue => e
          raise Domgen::Generator::GeneratorError.new("Error generating #{self.name} for #{element_type} #{object_name}", e)
        end
      end

      def wsdl2java(base_dir, service_name, output_package, target_version, wsdl_filename, wsdl_location)
        command = []
        command << 'wsimport'
        command << '-keep'
        command << '-Xnocompile'
        command << '-target'
        command << target_version
        command << '-s'
        command << base_dir
        command << '-p'
        command << output_package
        if wsdl_location
          command << '-wsdllocation'
          command << wsdl_location
        end
        command << wsdl_filename

        Logger.debug "Executing generator #{command.join(' ')}"
        output = `#{command.join(' ')}`
        if $? != 0
          puts output
          Domgen.error('Problem building webservices')
        end
        unless File.exist?("#{base_dir}/#{output_package.gsub('.','/')}/#{service_name}.java")
          puts output
          Domgen.error('Problem building webservices')
        end
        if output =~ /\[WARNING\]/
          puts output
        end
      end
    end
  end
end
