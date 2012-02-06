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

    class JsonMethod < Domgen.ParentedElement(:method)
      Domgen::JSON.include_json(self, :method)
    end

    class JsonParameter < Domgen.ParentedElement(:method)
      Domgen::JSON.include_json(self, :method)
    end

    class JsonEnumeration < Domgen.ParentedElement(:enumeration)
      Domgen::JSON.include_json(self, :enumeration)
    end
  end

  FacetManager.define_facet(:json,
                            Method => Domgen::JSON::JsonMethod,
                            Parameter => Domgen::JSON::JsonParameter,
                            Struct => Domgen::JSON::JsonStruct,
                            StructField => Domgen::JSON::JsonStructField,
                            EnumerationSet => Domgen::JSON::JsonEnumeration)
end
