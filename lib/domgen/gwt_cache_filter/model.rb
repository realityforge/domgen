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
  FacetManager.facet(:gwt_cache_filter => [:gwt]) do |facet|
    facet.enhance(Repository) do
      def pre_complete
        repository.ee.web_xml_content_fragments << <<XML

<!-- gwt_cache_filter fragment is auto-generated -->
  <filter>
    <filter-name>GWTCacheControlFilter</filter-name>
    <filter-class>org.realityforge.gwt.cache_filter.GWTCacheControlFilter</filter-class>
  </filter>
  <filter>
    <filter-name>GWTGzipFilter</filter-name>
    <filter-class>org.realityforge.gwt.cache_filter.GWTGzipFilter</filter-class>
  </filter>
  <filter-mapping>
    <filter-name>GWTCacheControlFilter</filter-name>
    <url-pattern>/#{repository.gwt.module_name}/*</url-pattern>
  </filter-mapping>
  <filter-mapping>
    <filter-name>GWTGzipFilter</filter-name>
    <url-pattern>/#{repository.gwt.module_name}/*</url-pattern>
  </filter-mapping>
<!-- gwt_cache_filter fragment end -->
XML
      end
    end
  end
end
