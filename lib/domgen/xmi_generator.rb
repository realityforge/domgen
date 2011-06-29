module Domgen
  module Xmi
    class GenerateXMITask
      attr_accessor :model_name
      attr_accessor :description
      attr_accessor :namespace_key

      attr_reader :repository_key
      attr_reader :key
      attr_reader :filename

      attr_reader :task_name

      def initialize(repository_key, key, filename)
        @repository_key, @key, @filename = repository_key, key, filename
        @namespace_key = :domgen
        yield self if block_given?
        define
      end

      private

      def define
        namespace self.namespace_key do
          desc self.description || "Generates the #{key} xmi artifacts."
          t = task self.key => ["#{self.namespace_key}:load"] do
            Domgen::Xmi.init_emf
            begin
              FileUtils.mkdir_p File.dirname(filename)
              Domgen::Xmi.generate_xmi(self.repository_key, self.model_name || self.repository_key, self.filename)
            rescue Exception => e
              print "An error occurred generating the xmi\n"
              puts $!
              puts $@
              raise e
            end
          end
          @task_name = t.name
        end
      end
    end

    def self.generate_xmi(repository_key, model_name, filename)
      repository = Domgen.repository_by_name(repository_key)

      output_file = Java.java.io.File.new(filename).get_absolute_path

      Resource::Factory::Registry::INSTANCE.getExtensionToFactoryMap().
        put( File.extname(output_file).gsub('.',''), UMLResource::Factory::INSTANCE )

      model = Java.org.eclipse.uml2.uml.UMLFactory.eINSTANCE.createModel()
      model.set_name(model_name.to_s)
      model.createOwnedComment().setBody(description(repository)) if description(repository)

      output_uri = Java.org.eclipse.emf.common.util.URI.createFileURI(output_file)
      puts "Creating XMI for repository #{repository_key} at #{output_file}"
      resource = Java.org.eclipse.emf.ecore.resource.impl.ResourceSetImpl.new.create_resource(output_uri)
      resource.get_contents().add(model)
      resource.setID( model, model_name.to_s )

      # As we process the schema set, we put all the packages that we discover inside this array
      # This is a map between package names and EMF package classes
      packages = {}

      # As we process the schema set, we put all the primitive types that we discover inside this map
      # This is a map between DB types to EMF primitive types
      primitive_types = {}

      # As we process the schema set, we put all the enumerations types that we discover inside this map
      # This is a map between enumeration keys and String version of enumeration type
      enumerations = {}

      # A map from fully qualified class names to EMF classes
      name_class_map = {}

      # Phase 1: Package, primitive type, and enumeration type discovery.
      # Primitive types will be added to the top-level model but enumeration types
      # will be added to the package they belong to.
      #
      # Only persistent and attributes will be processed.
      repository.data_modules.each do |data_module|
        package = model.create_nested_package(data_module.name.to_s)
        resource.setID( package, data_module.name.to_s )
        package.createOwnedComment().setBody(description(data_module)) if description(data_module)
        packages[data_module.name] = package

        data_module.object_types.each do |object_type|
          object_type.attributes.select { |attr| attr.persistent? }.each do |attribute|
            if attribute.enum?
              enum_key = create_enum_key(data_module, object_type, attribute)
              enum_name = create_enum_name(object_type, attribute)
              enum = package.create_owned_enumeration(enum_name)
              resource.setID( enum, "#{attribute.qualified_name}Enum" )
              attribute.values.each do |enum_literal, enum_index|
                literal = enum.create_owned_literal(enum_literal)
                resource.setID( literal, "#{attribute.qualified_name}Enum.#{enum_literal}" );
              end
              enumerations[enum_key] ||= enum
            elsif !attribute.reference?
              pn = primitive_name(attribute.attribute_type)
              if !primitive_types[pn]
                primitive_type = model.create_owned_primitive_type(pn)
                resource.setID(primitive_type, pn)
                primitive_types[pn] = primitive_type
              end
            end
          end
        end
      end

      # Phase 2: Class and association discovery. In this phase, we process the schema set and create a class
      # per each schema.
      repository.data_modules.each do |data_module|
        data_module.object_types.each do |object_type|
          package = packages[data_module.name]
          clazz = package.create_owned_class(object_type.name, false)
          resource.setID( clazz, object_type.qualified_name.to_s )
          clazz.createOwnedComment().setBody(description(object_type)) if description(object_type)
          name_class_map[object_type.qualified_name] ||= clazz

          # Creating EMF attributes corresponding to persistent, non-enum attributes
          object_type.attributes.select { |attr| attr.persistent? && !attr.enum? }.each do |attribute|
            attribute_type =
              attribute.reference? ? attribute.referenced_object.primary_key.attribute_type : attribute.attribute_type
            prim_type = primitive_types[primitive_name(attribute_type)]
            name = attribute.reference? ? attribute.referencing_link_name : attribute.name.to_s
            emf_attr = clazz.create_owned_attribute(name, prim_type, 0, 1)
            resource.setID( emf_attr, attribute.qualified_name.to_s )
            emf_attr.createOwnedComment().setBody(description(attribute)) if description(attribute)
          end

          # Creating EMF attributes corresponding to persistent enum attributes
          object_type.attributes.select { |attr| attr.persistent? && attr.enum? && !attr.reference? }.each do |attribute|
            enum_type = enumerations[create_enum_key(data_module, object_type, attribute)]
            emf_attr = clazz.create_owned_attribute(attribute.name.to_s, enum_type, 0, 1)
            resource.setID(emf_attr, attribute.qualified_name.to_s)
            emf_attr.createOwnedComment().setBody(description(attribute)) if description(attribute)
          end
        end
      end

      # Phase 3: Association building. In this phase, we process the schema set and create EMF associations
      # corresponding to the references defined in it.
      repository.data_modules.each do |data_module|
        data_module.object_types.each do |object_type|
          object_type.attributes.select { |attribute| attribute.persistent? && attribute.reference? }.each do |attribute|
            end1 = name_class_map[attribute.object_type.qualified_name]
            end2 = name_class_map[attribute.referenced_object.qualified_name]
            name = attribute.name == attribute.referenced_object.name ? "" : attribute.name.to_s
            emf_association = end1.create_association(true,
                                                      AggregationKind::NONE_LITERAL,
                                                      name,
                                                      attribute.nullable? ? 0 : 1,
                                                      1,
                                                      end2,
                                                      attribute.inverse_traversable?,
                                                      AggregationKind::NONE_LITERAL,
                                                      "",
                                                      0,
                                                      attribute.inverse_multiplicity == :many ? LiteralUnlimitedNatural::UNLIMITED : 1)
            resource.setID(emf_association, attribute.qualified_name.to_s + ".Assoc")
            emf_association.createOwnedComment().setBody(description(attribute)) if description(attribute)
          end
        end
      end

      resource.save(nil)

    end

    private

    @@init_emf = false

    def self.init_emf
      return if @@init_emf == true
      @@init_emf = true
      require 'buildr'
      require 'java'
      ::Java.classpath << Buildr.transitive('org.eclipse.uml2:org.eclipse.uml2.uml:jar:3.1.0.v201006071150')
      ::Java.load

      java_import org.eclipse.emf.ecore.resource.Resource
      java_import org.eclipse.uml2.uml.resource.UMLResource
      java_import org.eclipse.uml2.uml.AggregationKind
      java_import org.eclipse.uml2.uml.LiteralUnlimitedNatural
    end

    def self.description(element)
      element.tag_as_html(:Description)
    end

    def self.primitive_name(attribute_type)
      return "string" if attribute_type == :text
      return "int" if attribute_type == :integer
      return attribute_type.to_s
    end

    def self.create_enum_key(schema, object_type, attr)
      "#{schema.name}.#{object_type.name}.#{attr.name}"
    end

    def self.create_enum_name(object_type, attr)
      "#{object_type.name}#{attr.name}Enum"
    end
  end
end
