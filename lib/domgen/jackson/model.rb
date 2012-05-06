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
