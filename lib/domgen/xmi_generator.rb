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
          unless Rake::Task.task_defined?("init_emf")
            task "init_emf" do
              require 'buildr'
              require 'java'

              ::Java.classpath << Buildr.transitive('org.eclipse.uml2:org.eclipse.uml2.uml:jar:3.1.0.v201006071150')
              ::Java.load

              java_import org.eclipse.emf.ecore.resource.Resource
              java_import org.eclipse.uml2.uml.resource.UMLResource
              java_import org.eclipse.uml2.uml.AggregationKind
              java_import org.eclipse.uml2.uml.LiteralUnlimitedNatural
            end
          end

          desc self.description || "Generates the #{key} xmi artifacts."
          t = task self.key => ["#{self.namespace_key}:load", "#{self.namespace_key}:init_emf"] do
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
      output_file = Java.java.io.File.new(filename).get_absolute_path

      Resource::Factory::Registry::INSTANCE.getExtensionToFactoryMap().
        put( File.extname(output_file).gsub('.',''), UMLResource::Factory::INSTANCE )

      model = Java.org.eclipse.uml2.uml.UMLFactory.eINSTANCE.createModel()
      model.set_name(model_name.to_s)

      output_uri = Java.org.eclipse.emf.common.util.URI.createFileURI(output_file)
      puts "Creating XMI for repository #{repository_key} at #{output_file}"
      resource = Java.org.eclipse.emf.ecore.resource.impl.ResourceSetImpl.new.create_resource(output_uri)
      resource.get_contents().add(model)

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

      # Some object types have attributes that are references to other object types. Besides, each object type is
      # converted to an EMF class. reference_map is a map between an EMF class to all the references to other
      # object_types it has. This map will be used in the association generation phase to create associations between
      # EMF classes in the model
      reference_map = {}

      repository = Domgen.repository_by_name(repository_key)

      # Phase 1: Package, primitive type, and enumeration type discovery.
      # Primitive types will be added to the top-level model but enumeration types
      # will be added to the package they belong to.
      #
      # Only persistent and attributes will be processed.
      repository.data_modules.each do |data_module|
        package = model.create_nested_package(data_module.name.to_s)
        packages[data_module.name] = package

        data_module.object_types.each do |object_type|
          object_type.attributes.select { |attr| attr.persistent? }.each do |attribute|
            if attribute.enum?
              enum_key = create_enum_key(data_module, object_type, attribute)
              enum_name = create_enum_name(object_type, attribute)
              enum = package.create_owned_enumeration(enum_name)
              attribute.values.each do |enum_literal, enum_index|
                enum.create_owned_literal(enum_literal)
              end
              enumerations[enum_key] ||= enum
            else
              attr_type =
                attribute.reference? ? attribute.referenced_object.primary_key.attribute_type : attribute.attribute_type
              primitive_types[attr_type.to_s] ||= model.create_owned_primitive_type(attr_type.to_s)
            end
          end
        end
      end

      # Phase 2: Class and association discovery. In this phase, we process the schema set and create a class
      # per each schema. We also populate the reference_map in this phase. The reference_map will be used in
      # the next phase to build associations
      repository.data_modules.each do |data_module|
        data_module.object_types.each do |object_type|
          package = packages[data_module.name]
          clazz = package.create_owned_class(object_type.name, false)
          name_class_map[object_type.qualified_name] ||= clazz

          # Creating EMF attributes corresponding to persistent, non-enum, non-reference attributes
          object_type.attributes.select { |attr| attr.persistent? && !attr.enum? && !attr.reference? }.each do |attr|
            prim_type = primitive_types[attr.attribute_type.to_s]
            clazz.create_owned_attribute(attr.name.to_s, prim_type, 0, 1)
          end

          # Creating EMF attributes corresponding to persistent, reference, non-enum attributes
          object_type.attributes.select { |attr| attr.persistent? && !attr.enum? && attr.reference? }.each do |attr|
            prim_type = primitive_types[attr.referenced_object.primary_key.attribute_type.to_s]
            clazz.create_owned_attribute(attr.referencing_link_name.to_s, prim_type, 0, 1)
            if (reference_map[clazz])
              reference_map[clazz] << attr
            else
              reference_map[clazz] = [attr]
            end
          end

          # Creating EMF attributes corresponding to persistent, enum, non-reference attributes
          object_type.attributes.select { |attr| attr.persistent? && attr.enum? && !attr.reference? }.each do |attr|
            enum_type = enumerations[create_enum_key(data_module, object_type, attr)]
            clazz.create_owned_attribute(attr.name.to_s, enum_type, 0, 1)
          end
        end
      end

      # Phase 3: Association building. In this phase, we process the schema set and create EMF associations
      # corresponding to the references defined in it.
      reference_map.each do |end1, references|
        references.each do |ref|
          end2 = name_class_map[ref.referenced_object.qualified_name]
          end1.create_association(
            true,
            AggregationKind::NONE_LITERAL,
            "",
            ref.nullable? ? 0 : 1,
            1,
            end2,
            ref.inverse_relationship_type == :none ? false : true,
            AggregationKind::NONE_LITERAL,
            "",
            0,
            ref.inverse_relationship_type == :has_many ? LiteralUnlimitedNatural::UNLIMITED : 1
          )
        end
      end

      resource.save(nil)

    end

    private

    def self.create_enum_key(schema, object_type, attr)
      "#{schema.name}.#{object_type.name}.#{attr.name}"
    end

    def self.create_enum_name(object_type, attr)
      "#{object_type.name}#{attr.name}Enum"
    end
  end
end
