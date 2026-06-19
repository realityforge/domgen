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
  module Generators #nodoc
    module Buildr
      class << self
        # This method is called from a Rake or Buildr task to configure the Buildr
        # project so that it knows the location of all the generated artifacts and
        # adds them to the appropriate compile paths etc.
        def configure_buildr_project(buildr_project, generator_task, templates, target_dir, mark_as_generated_in_ide, clean_files = true)
          if buildr_project.nil?
            if clean_files
              task('clean') do
                rm_rf target_dir
              end
            end
          else
            if clean_files
              buildr_project.clean { rm_rf target_dir }
            end
            file(File.expand_path(target_dir) => [generator_task])

            # Is there java source generated in project?
            if templates.any? { |template| template.output_path =~ /^main\/java\/.*/ }
              main_java_dir = "#{target_dir}/main/java"
              file(main_java_dir => [generator_task]) do
                mkdir_p main_java_dir
              end
              buildr_project.compile.using :javac
              buildr_project.compile.from main_java_dir
              # Need to force this as it may have already been cached and thus will not recalculate
              buildr_project.iml.main_generated_source_directories << main_java_dir if mark_as_generated_in_ide && buildr_project.iml?
            end

            # Is there resources generated in project?
            if templates.any? { |template| template.output_path =~ /^main\/resources\/.*/ }
              main_resources_dir = "#{target_dir}/main/resources"
              file(main_resources_dir => [generator_task]) do
                mkdir_p main_resources_dir
              end
              buildr_project.resources.enhance([generator_task])
              buildr_project.resources.filter.into buildr_project.path_to(:target, :main, :resources) unless buildr_project.resources.target
              buildr_project.resources do |t|
                t.enhance do
                  if File.exist?(main_resources_dir)
                    FileUtils.mkdir_p buildr_project.resources.target.to_s
                    FileUtils.cp_r "#{main_resources_dir}/.", buildr_project.resources.target.to_s
                  end
                end
              end
              buildr_project.iml.main_generated_resource_directories << main_resources_dir if mark_as_generated_in_ide && buildr_project.iml?
            end

            # Is there assets generated in project?
            if templates.any? { |template| template.output_path =~ /^main\/webapp\/.*/ }
              webapp_dir = File.expand_path("#{target_dir}/main/webapp")
              buildr_project.assets.enhance([generator_task])
              buildr_project.assets.paths << file(webapp_dir => [generator_task]) do
                mkdir_p webapp_dir
              end
            end

            # Is there test java source generated in project?
            if templates.any? { |template| template.output_path =~ /^test\/java\/.*/ }
              test_java_dir = "#{target_dir}/test/java"
              file(test_java_dir => [generator_task]) do
                mkdir_p test_java_dir
              end
              buildr_project.test.compile.from test_java_dir
              # Need to force this as it may have already been cached and thus will not recalculate
              buildr_project.iml.test_generated_source_directories << test_java_dir if mark_as_generated_in_ide && buildr_project.iml?
            end

            # Is there resources generated in project?
            if templates.any? { |template| template.output_path =~ /^test\/resources\/.*/ }
              test_resources_dir = "#{target_dir}/test/resources"
              file(test_resources_dir => [generator_task]) do
                mkdir_p test_resources_dir
              end
              buildr_project.test.resources.enhance([generator_task])
              buildr_project.test.resources.filter.into buildr_project.path_to(:target, :test, :resources) unless buildr_project.test.resources.target
              buildr_project.test.resources do |t|
                t.enhance do
                  if File.exist?(test_resources_dir)
                    FileUtils.mkdir_p buildr_project.test.resources.target.to_s
                    FileUtils.cp_r "#{test_resources_dir}/.", buildr_project.test.resources.target.to_s
                  end
                end
              end
              buildr_project.iml.test_generated_resource_directories << test_resources_dir if mark_as_generated_in_ide && buildr_project.iml?
            end
          end
        end
      end
    end
  end
end
