module Domgen
  module AutoBean
    class AutoBeanStruct < Domgen.ParentedElement(:struct)
      attr_writer :name

      def name
        @name || struct.name
      end

      def qualified_name
        "#{struct.data_module.auto_bean.data_type_package}.#{self.name}"
      end
    end

    class AutoBeanbStructField < Domgen.ParentedElement(:field)
      include Domgen::Java::AutoBeanJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end

    class AutoBeanEnumeration < Domgen.ParentedElement(:enumeration)
      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.auto_bean.data_type_package}.#{name}"
      end
    end

    class AutoBeanPackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

      protected

      def facet_key
        :auto_bean
      end
    end

    class AutoBeanApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ClientJavaApplication
    end
  end

  FacetManager.define_facet(:auto_bean,
                            Struct => Domgen::AutoBean::AutoBeanStruct,
                            StructField => Domgen::AutoBean::AutoBeanbStructField,
                            EnumerationSet => Domgen::AutoBean::AutoBeanEnumeration,
                            DataModule => Domgen::AutoBean::AutoBeanPackage,
                            Repository => Domgen::AutoBean::AutoBeanApplication)

end
