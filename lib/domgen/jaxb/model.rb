module Domgen
  module JAXB
    class JaxbStructField < Domgen.ParentedElement(:field)
    end

    class JaxbStruct < Domgen.ParentedElement(:struct)
    end

    class JaxbEnumeration < Domgen.ParentedElement(:enumeration)
    end

    class JaxbDataModule < Domgen.ParentedElement(:data_module)
    end

    class JaxbPackage < Domgen.ParentedElement(:repository)
    end
  end

  FacetManager.define_facet(:jaxb,
                            {
                              Struct => Domgen::JAXB::JaxbStruct,
                              StructField => Domgen::JAXB::JaxbStructField,
                              EnumerationSet => Domgen::JAXB::JaxbEnumeration,
                              DataModule => Domgen::JAXB::JaxbDataModule,
                              Repository => Domgen::JAXB::JaxbPackage
                            },
                            [:xml, :ee])
end
