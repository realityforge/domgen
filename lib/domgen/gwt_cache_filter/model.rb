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
  FacetManager.facet(:gwt_cache_filter) do |facet|
    facet.description = <<DESC
The gwt_cache_filter facet configures the is enabled to add a filter that matches files named
*.cache.* and *.nocache.* and sets caching http headers as appropriate. It also adds the filter
that serves pre-encoded brotli resources if available. Despite the name, the facet can be used
with both gwt and non-gwt applications.
DESC
    facet.enhance(Repository) do
      def add_brotli_filter_path(path)
        brotli_filter_path_list << path
      end

      def brotli_filter_paths
        brotli_filter_path_list.dup
      end

      def add_cache_control_filter_path(path)
        cache_control_filter_path_list << path
      end

      def cache_control_filter_paths
        cache_control_filter_path_list.dup
      end

      def post_complete
        if self.brotli_filter_paths.empty? && self.cache_control_filter_paths.empty?
          repository.disable_facet(:gwt_cache_filter)
        end
        unless self.cache_control_filter_paths.empty?
          fragment = <<XML
  <!-- #{repository.name}.CacheControlFilter fragment is auto-generated -->
  <filter>
    <filter-name>#{repository.name}.CacheControlFilter</filter-name>
    <filter-class>org.realityforge.gwt.cache_filter.GWTCacheControlFilter</filter-class>
  </filter>
  <filter-mapping>
    <filter-name>#{repository.name}.CacheControlFilter</filter-name>
XML
          self.cache_control_filter_paths.each do |path|
            fragment += <<XML
    <url-pattern>#{path}</url-pattern>
XML
          end
          fragment += <<XML
  </filter-mapping>
  <!-- #{repository.name}.CacheControlFilter fragment end -->
XML
          repository.ee.web_xml_content_fragments << fragment
        end
 unless self.brotli_filter_paths.empty?
          fragment = <<XML
  <!-- #{repository.name}.BrotliFilter fragment is auto-generated -->
  <filter>
    <filter-name>#{repository.name}.BrotliFilter</filter-name>
    <filter-class>org.realityforge.gwt.cache_filter.PreEncodedBrotliFilter</filter-class>
  </filter>
  <filter-mapping>
    <filter-name>#{repository.name}.BrotliFilter</filter-name>
XML
          self.brotli_filter_paths.each do |path|
            fragment += <<XML
    <url-pattern>#{path}</url-pattern>
XML
          end
          fragment += <<XML
  </filter-mapping>
  <!-- #{repository.name}.BrotliFilter fragment end -->
XML
          repository.ee.web_xml_content_fragments << fragment
        end
      end

      private

      def brotli_filter_path_list
        (@brotli_filter_paths ||= [])
      end

      def cache_control_filter_path_list
        (@cache_control_filter_paths ||= [])
      end
    end
  end
end
