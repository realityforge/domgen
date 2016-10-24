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
  class ZipUtil
    @@pre_1_zip_gem = nil

    def self.use_pre_1_zip_gem!
      @@pre_1_zip_gem = true
    end

    def self.use_pre_1_zip_gem?
      @@pre_1_zip_gem.nil? ? (defined?(::Buildr) && ::Buildr::VERSION.to_s < '1.5.0') : !!@@pre_1_zip_gem
    end

    # Read the contents of a file contained in a zip, return nil if it does not exist
    def self.read_file(zip_filename, filename)
      return nil unless File.exist?(zip_filename)
      (use_pre_1_zip_gem? ? Zip::ZipFile : Zip::File).open(zip_filename) do |zip|
        return file_exist?(zip, filename) ? read(zip, filename) : nil
      end
    end

    private

    def self.file_exist?(zip, filename)
      use_pre_1_zip_gem? ? zip.file.exist?(filename) : !zip.find_entry(filename).nil?
    end

    def self.read(zip, filename)
      (use_pre_1_zip_gem? ? zip.file : zip).read(filename)
    end
  end
end
