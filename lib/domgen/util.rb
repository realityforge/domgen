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
  class Util

    # Extract the contents of template from an artifact
    def self.extract_template_from_artifact(artifact_spec, template_filename)
      contents = Domgen::Util.load_file_from_artifact(artifact_spec, template_filename)
      Domgen::Util.extract_template_contents(contents)
    end

    # Retrieve the children of the xml template provided
    def self.extract_template_contents(contents)
      require 'rexml/document'
      document = REXML::Document.new(contents)
      document.root.children.collect { |c| c.to_s }.join("\n")
    end

    # Attempt to load a file from an artifact as specified.
    # The artifact_spec should be sufficient to uniquely identify
    # artifact. This method will return nil of no such file exists.
    def self.load_file_from_artifact(artifact_spec, filename)
      zip_filename = Domgen.resolve_artifact(artifact_spec)
      contents = Domgen::ZipUtil.read_file(zip_filename, filename)
      raise "Unable to locate file '#{filename}' in artifact '#{artifact_spec}' at '#{zip_filename}'" unless contents
      contents
    end
  end
end
