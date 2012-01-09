module Domgen
  module JSON

    def self.include_json(type, parent_key)
      type.class_eval(<<-RUBY)
      attr_writer :name

      def name
        @name || Domgen::Naming.jsonize(#{parent_key}.name)
      end
RUBY
    end

    class JsonStructField < Domgen.ParentedElement(:field)
      Domgen::JSON.include_json(self, :field)
    end

    class JsonStruct < Domgen.ParentedElement(:struct)
      Domgen::JSON.include_json(self, :struct)
    end

    class JsonEnumeration < Domgen.ParentedElement(:enumeration)
      Domgen::JSON.include_json(self, :enumeration)
    end
  end

  FacetManager.define_facet(:json,
                            Struct => Domgen::JSON::JsonStruct,
                            StructField => Domgen::JSON::JsonStructField,
                            EnumerationSet => Domgen::JSON::JsonEnumeration)
end
