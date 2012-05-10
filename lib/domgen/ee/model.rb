module Domgen
  module EE
    class EeExceptionParameter < Domgen.ParentedElement(:parameter)
      include Domgen::Java::EEJavaCharacteristic

      def name
        parameter.name
      end

      protected

      def characteristic
        parameter
      end
    end

    class EeException < Domgen.ParentedElement(:exception)
      def name
        exception.name.to_s =~ /Exception$/ ? exception.name.to_s : "#{exception.name}Exception"
      end

      def qualified_name
        "#{exception.data_module.ee.service_package}.#{name}"
      end
    end

    class EeStruct < Domgen.ParentedElement(:struct)
      attr_writer :name

      def name
        @name || struct.name
      end

      def qualified_name
        "#{struct.data_module.ee.data_type_package}.#{self.name}"
      end
    end

    class EebStructField < Domgen.ParentedElement(:field)
      include Domgen::Java::EEJavaCharacteristic

      def name
        field.name
      end

      protected

      def characteristic
        field
      end
    end

    class EeEnumeration < Domgen.ParentedElement(:enumeration)
      def name
        "#{enumeration.name}"
      end

      def qualified_name
        "#{enumeration.data_module.ee.data_type_package}.#{name}"
      end
    end

    class EePackage < Domgen.ParentedElement(:data_module)
      include Domgen::Java::JavaPackage

      protected

      def facet_key
        :ee
      end
    end

    class EeApplication < Domgen.ParentedElement(:repository)
      include Domgen::Java::ServerJavaApplication
    end
  end

  FacetManager.define_facet(:ee,
                            Exception => Domgen::EE::EeException,
                            ExceptionParameter => Domgen::EE::EeExceptionParameter,
                            Struct => Domgen::EE::EeStruct,
                            StructField => Domgen::EE::EebStructField,
                            EnumerationSet => Domgen::EE::EeEnumeration,
                            DataModule => Domgen::EE::EePackage,
                            Repository => Domgen::EE::EeApplication)

end
