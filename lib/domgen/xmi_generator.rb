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
        # Need to init emf now otherwise Buildr will not have jars loaded into classpath
        Domgen::Xmi.init_emf
        namespace self.namespace_key do
          desc self.description || "Generates the #{key} xmi artifacts."
          t = task self.key => ["#{self.namespace_key}:load"] do
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

      output_file = ::Java.java.io.File.new(filename).getAbsolutePath()

      ::Java.org.eclipse.emf.ecore.resource.Resource::Factory::Registry::INSTANCE.getExtensionToFactoryMap().
        put(File.extname(output_file).gsub('.', ''), Java.org.eclipse.uml2.uml.resource.UMLResource::Factory::INSTANCE)

      model = ::Java.org.eclipse.uml2.uml.UMLFactory.eINSTANCE.createModel()
      model.set_name(model_name.to_s)
      model.createOwnedComment().setBody(description(repository)) if description(repository)

      output_uri = ::Java.org.eclipse.emf.common.util.URI.createFileURI(output_file)
      puts "Creating XMI for repository #{repository_key} at #{output_file}"
      resource = ::Java.org.eclipse.emf.ecore.resource.impl.ResourceSetImpl.new.create_resource(output_uri)
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
        resource.setID(package, data_module.name.to_s)
        package.createOwnedComment().setBody(description(data_module)) if description(data_module)
        packages[data_module.name] = package

        data_module.entities.each do |entity|
          entity.attributes.select { |attr| attr.persistent? }.each do |attribute|
            if attribute.enum?
              enum_key = create_enum_key(data_module, entity, attribute)
              enum_name = create_enum_name(entity, attribute)
              enum = package.create_owned_enumeration(enum_name)
              resource.setID(enum, "#{attribute.qualified_name}Enum")
              attribute.enumeration.values.each do |enum_literal, enum_index|
                literal = enum.create_owned_literal(enum_literal)
                resource.setID(literal, "#{attribute.qualified_name}Enum.#{enum_literal}");
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
        data_module.entities.each do |entity|
          package = packages[data_module.name]
          clazz = package.create_owned_class(entity.name, false)
          resource.setID(clazz, entity.qualified_name.to_s)
          clazz.createOwnedComment().setBody(description(entity)) if description(entity)
          name_class_map[entity.qualified_name] ||= clazz

          # Creating EMF attributes corresponding to persistent, non-enum attributes
          entity.attributes.select { |attr| attr.persistent? && !attr.enum? }.each do |attribute|
            attribute_type =
              attribute.reference? ? attribute.referenced_entity.primary_key.attribute_type : attribute.attribute_type
            prim_type = primitive_types[primitive_name(attribute_type)]
            name = attribute.reference? ? attribute.referencing_link_name : attribute.name.to_s
            emf_attr = clazz.create_owned_attribute(name, prim_type, 0, 1)
            resource.setID(emf_attr, attribute.qualified_name.to_s)
            emf_attr.createOwnedComment().setBody(description(attribute)) if description(attribute)
          end

          # Creating EMF attributes corresponding to persistent enum attributes
          entity.attributes.select { |attr| attr.persistent? && attr.enum? && !attr.reference? }.each do |attribute|
            enum_type = enumerations[create_enum_key(data_module, entity, attribute)]
            emf_attr = clazz.create_owned_attribute(attribute.name.to_s, enum_type, 0, 1)
            resource.setID(emf_attr, attribute.qualified_name.to_s)
            emf_attr.createOwnedComment().setBody(description(attribute)) if description(attribute)
          end
        end
      end

      # Phase 3: Association building. In this phase, we process the schema set and create EMF associations
      # corresponding to the references defined in it.
      repository.data_modules.each do |data_module|
        data_module.entities.each do |entity|
          entity.attributes.select { |attribute| attribute.persistent? && attribute.reference? }.each do |attribute|
            end1 = name_class_map[attribute.entity.qualified_name]
            end2 = name_class_map[attribute.referenced_entity.qualified_name]
            name = attribute.name == attribute.referenced_entity.name ? "" : attribute.name.to_s

            aggregation_kind = Java.org.eclipse.uml2.uml.AggregationKind::NONE_LITERAL
            aggregation_kind = Java.org.eclipse.uml2.uml.AggregationKind::SHARED_LITERAL if attribute.inverse.relationship_kind == :aggregation
            aggregation_kind = Java.org.eclipse.uml2.uml.AggregationKind::COMPOSITE_LITERAL if attribute.inverse.relationship_kind == :composition

            emf_association = end1.create_association(true,
                                                      aggregation_kind,
                                                      name,
                                                      attribute.nullable? ? 0 : 1,
                                                      1,
                                                      end2,
                                                      attribute.inverse.traversable?,
                                                      Java.org.eclipse.uml2.uml.AggregationKind::NONE_LITERAL,
                                                      "",
                                                      0,
                                                      attribute.inverse.multiplicity == :many ? Java.org.eclipse.uml2.uml.LiteralUnlimitedNatural::UNLIMITED : 1)
            resource.setID(emf_association, attribute.qualified_name.to_s + ".Assoc")
            emf_association.createOwnedComment().setBody(description(attribute)) if description(attribute)
          end
        end
      end

      # Phase 4: Service creation. In this phase, we process the repository and create a class or each service.
      repository.data_modules.each do |data_module|
        data_module.services.each do |service|
          package = packages[data_module.name]
          clazz = package.create_owned_class(service.name, false)
          resource.setID(clazz, service.qualified_name.to_s)
          clazz.createOwnedComment().setBody(description(service)) if description(service)
          name_class_map[service.qualified_name] ||= clazz

          service.methods.each do |method|
            package = packages[data_module.name]
            names = Java.org.eclipse.emf.common.util.BasicEList.new(method.parameters.size)
            types = Java.org.eclipse.emf.common.util.BasicEList.new(method.parameters.size)

            method.parameters.each do |p|
              p_type_str = p.parameter_type.to_s
              param_type = if (name_class_map.has_key?(p_type_str))
                name_class_map[p_type_str]
              else
                name_class_map[p_type_str] = package.create_owned_class(p_type_str, false)
                name_class_map[p_type_str]
              end
              types.add(param_type)
              names.add(p.name.to_s)
            end

            operation = if method.return_value.return_type != :void
              return_type_str = method.return_value.return_type.to_s
              return_type = if (name_class_map.has_key?(return_type_str))
                name_class_map[return_type_str]
              else
                name_class_map[return_type_str] = package.create_owned_class(return_type_str, false)
                name_class_map[return_type_str]
              end
              clazz.createOwnedOperation(method.name.to_s, names, types, return_type)
            else
              clazz.createOwnedOperation(method.name.to_s, names, types)
            end
            resource.setID( operation, method.qualified_name.to_s )
            operation.createOwnedComment().setBody(description(method)) if description(method)
          end
        end
      end

      # Phase 5: Message creation.
      repository.data_modules.each do |data_module|
        data_module.messages.each do |message|
          class_name = "#{message.name}Message"
          package = packages[data_module.name]
          clazz = package.create_owned_class(class_name, false)
          resource.setID(clazz, message.qualified_name.to_s)
          clazz.createOwnedComment().setBody(description(message)) if description(message)
          name_class_map[message.qualified_name] ||= clazz

          message.parameters.each do |param|
            create_accessors(clazz, param, resource)
          end
        end
      end

      # Phase 6: Exception creation.
      repository.data_modules.each do |data_module|
        package = packages[data_module.name]
        data_module.exceptions.each do |exception|
          class_name = "#{exception.name}Exception"
          clazz = package.create_owned_class(class_name, false)
          resource.setID(clazz, exception.qualified_name.to_s)
          clazz.createOwnedComment().setBody(description(exception)) if description(exception)
          name_class_map[exception.qualified_name] ||= clazz
        end
      end

      resource.save(nil)

    end

    private

    @@init_emf = false

    def self.init_emf
      return if @@init_emf == true
      @@init_emf = true
      ::Java.classpath << Buildr.transitive('org.eclipse.uml2:org.eclipse.uml2.uml:jar:3.1.0.v201006071150')
      ::Java.load
    end

    def self.description(element)
      element.tag_as_html(:Description)
    end

    def self.primitive_name(attribute_type)
      return "string" if attribute_type == :text
      return "int" if attribute_type == :integer
      return attribute_type.to_s
    end

    def self.create_enum_key(schema, entity, attr)
      "#{schema.name}.#{entity.name}.#{attr.name}"
    end

    def self.create_enum_name(entity, attr)
      "#{entity.name}#{attr.name}Enum"
    end

    def self.create_accessors(clazz, param, resource)
      create_getter(clazz, param, resource)
      create_setter(clazz, param, resource)
    end

    def self.create_getter(clazz, param, resource)
      getter = "get#{create_property_name(param.name)}"
      getter_names = Java.org.eclipse.emf.common.util.BasicEList.new(0)
      getter_types = Java.org.eclipse.emf.common.util.BasicEList.new(0)
      ##TODO: Add name/parameter types
      operation = clazz.createOwnedOperation(getter, getter_names, getter_types)
      resource.setID(operation, param.qualified_name + "get")
    end

    def self.create_setter(clazz, param, resource)
      setter = "set#{create_property_name(param.name)}"
      setter_names = Java.org.eclipse.emf.common.util.BasicEList.new(0)
      setter_types = Java.org.eclipse.emf.common.util.BasicEList.new(0)
      ##TODO: Add name/parameter types
      operation = clazz.createOwnedOperation(setter, setter_names, setter_types)
      resource.setID(operation, param.qualified_name + "set")
    end

    def self.create_property_name(name)
      n = name.to_s
      "#{n[0, 1].upcase}#{n[1, n.length]}"
    end
  end
end
