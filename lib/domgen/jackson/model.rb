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
  module Jackson
    class JacksonStructField < Domgen.ParentedElement(:field)
    end

    class JacksonStruct < Domgen.ParentedElement(:struct)
    end

    class JacksonEnumeration < Domgen.ParentedElement(:enumeration)
    end

    class JacksonDataModule < Domgen.ParentedElement(:data_module)
    end

    class JacksonPackage < Domgen.ParentedElement(:repository)
    end
  end

  FacetManager.define_facet(:jackson,
                            {
                              Struct => Domgen::Jackson::JacksonStruct,
                              StructField => Domgen::Jackson::JacksonStructField,
                              EnumerationSet => Domgen::Jackson::JacksonEnumeration,
                              DataModule => Domgen::Jackson::JacksonDataModule,
                              Repository => Domgen::Jackson::JacksonPackage
                            },
                            [:json])
end
