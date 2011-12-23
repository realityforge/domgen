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
        namespace self.namespace_key do
          desc self.description || "Generates the #{key} xmi artifacts."
          t = task self.key => ["#{self.namespace_key}:load"] do
            begin
              Domgen::Xmi.init_emf

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

    def self.generate_xmi(repository_key, model_name, filename, profile_name = "Profile")
      resource_set = ::Java.org.eclipse.emf.ecore.resource.impl.ResourceSetImpl.new

      repository = Domgen.repository_by_name(repository_key)

      output_file = ::Java.java.io.File.new(filename).getAbsolutePath()

      ::Java.org.eclipse.uml2.uml.UMLPackage.eINSTANCE.getName()
      register_extensions(resource_set)
      puts "Register"

      register_pathmaps
      puts "Pathmaps"



      ::Java.org.eclipse.emf.ecore.resource.Resource::Factory::Registry::INSTANCE.getExtensionToFactoryMap().
        put(File.extname(output_file).gsub('.', ''), Java.org.eclipse.uml2.uml.resource.UMLResource::Factory::INSTANCE)

      profile = ::Java.org.eclipse.uml2.uml.UMLFactory.eINSTANCE.createProfile()
      profile.set_name(profile_name)

      model = ::Java.org.eclipse.uml2.uml.UMLFactory.eINSTANCE.createModel()
      model.set_name(model_name.to_s)
      model.createOwnedComment().setBody(description(repository)) if description(repository)

      emfUri = ::Java.org.eclipse.emf.common.util.URI
      output_uri = emfUri::createFileURI(output_file)
      puts "Creating XMI for repository #{repository_key} at #{output_file}"

      resource = resource_set.create_resource(output_uri)

      resource.get_contents().add(model)
      resource.get_contents().add(profile)

      resource.setID(model, "M_" + model_name.to_s)
      resource.setID(profile, "P_" + profile_name)

      message_stereotype = create_stereotype(profile, resource, "Message")

      umlMetaModel = load_package(resource_set, ::Java.org.eclipse.uml2.uml.resource.XMI2UMLResource.UML_METAMODEL_2_1_URI)

      extend_meta_class(umlMetaModel, profile, resource, "Class", ::Java.org.eclipse.uml2.uml.UMLPackage.Literals.CLASS.getName(), message_stereotype)
      profilePackage = profile.define
      resource.setID( profilePackage, "P_PKG_" + profile.getName())

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
      repository.data_modules.each do |data_module|
        package = model.create_nested_package(data_module.name.to_s)
        resource.setID(package, data_module.name.to_s)
        package.createOwnedComment().setBody(description(data_module)) if description(data_module)
        packages[data_module.name] = package

        data_module.entities.each do |entity|
          entity.attributes.each do |attribute|
            if attribute.enumeration?
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

          # Creating EMF attributes corresponding to non-enum attributes
          entity.attributes.select { |attr| !attr.enumeration? }.each do |attribute|
            attribute_type =
              attribute.reference? ? attribute.referenced_entity.primary_key.attribute_type : attribute.attribute_type
            prim_type = primitive_types[primitive_name(attribute_type)]
            name = attribute.reference? ? attribute.referencing_link_name : attribute.name.to_s
            emf_attr = clazz.create_owned_attribute(name, prim_type, 0, 1)
            resource.setID(emf_attr, attribute.qualified_name.to_s)
            emf_attr.createOwnedComment().setBody(description(attribute)) if description(attribute)
          end

          # Creating EMF attributes corresponding to enum attributes
          entity.attributes.select { |attr| attr.enumeration? && !attr.reference? }.each do |attribute|
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
          entity.attributes.select { |attribute| attribute.reference? }.each do |attribute|
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
              p_type_str.gsub!(/</, "[")
              p_type_str.gsub!(/>/, "]")
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
              return_type_str.gsub!(/</, "[")
              return_type_str.gsub!(/>/, "]")
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
        package = packages[data_module.name]
        data_module.messages.each do |message|
          msg_class_name = "#{message.name}Message"
          msg_class = package.create_owned_class(msg_class_name, false)
          msg_qualified_name = message.qualified_name.to_s
          resource.setID(msg_class, msg_qualified_name)
          msg_class.createOwnedComment().setBody(description(message)) if description(message)
          name_class_map[msg_qualified_name] ||= msg_class

          message.parameters.each do |param|
            param_name = param.name.to_s
            param_type_str = param.parameter_type.to_s
            param_type_str.gsub!(/</, "[")
            param_type_str.gsub!(/>/, "]")
            param_type = name_class_map[param_type_str]
            if param_type.nil?
              param_type = package.create_owned_class(param_type_str, false)
              resource.setID( param_type, param_type_str )
              name_class_map[param_type_str] = param_type
            end
            msg_class.create_owned_attribute(param_name, param_type, 0, 1)
          end
        end
      end

      # Phase 7: Exception creation.
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
        #uml2_direct_dependencies = [
        #  'org.eclipse.uml2:org.eclipse.uml2.uml:jar:3.1.0.v201006071150',
        #  'org.eclipse.uml2:org.eclipse.uml2.uml.resources:jar:3.1.0.v201005031530',
        #  'org.eclipse.uml2:org.eclipse.uml2.common:jar:1.5.0.v201005031530',
        #  'org.eclipse.emf:org.eclipse.emf.ecore:jar:2.6.0.v20100614-1136',
        #  'org.eclipse.emf:org.eclipse.emf.common:jar:2.6.0.v20100614-1136',
        #  'org.eclipse.emf:org.eclipse.emf.mapping.ecore2xml:jar:2.5.0.v20100521-1847',
        #  'org.eclipse.emf:org.eclipse.emf.ecore.xmi:jar:2.5.0.v20100521-1846',
        #]
      Buildr.transitive('org.eclipse.core:runtime:jar:3.3.100-v20070530').each do |artifact|
        $CLASSPATH << artifact.to_s
      end
      Buildr.transitive('org.eclipse.uml2:org.eclipse.uml2.uml:jar:3.1.0.v201006071150').each do |artifact|
        $CLASSPATH << artifact.to_s
      end
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

    def self.create_stereotype(profile, resource, stereotype_name)
      stereotype = profile.createOwnedStereotype( stereotype_name, false )
      resource.setID( stereotype, "STEREOTYPE_" + stereotype.getName() )
      stereotype
    end

    def self.load_package(resource_set, uri)
      res = resource_set.getResource( ::Java.org.eclipse.emf.common.util.URI.createURI(uri), true )
      ::Java.org.eclipse.emf.ecore.util.EcoreUtil.resolveAll( res )
      ::Java.org.eclipse.emf.ecore.util.EcoreUtil.getObjectByType( res.getContents(), Literals.PACKAGE )
    end

    def self.extend_meta_class(umlMetaModel, profile, resource, key, name, stereotype)
      appliedStereotype = stereotype.createExtension( reference_meta_class(umlMetaModel, profile, resource, name), false);
      resource.setID(appliedStereotype, "STEREO_" + stereotype.getName() + "_" + key)
    end

    def self.reference_meta_class(umlMetaModel, profile, resource, name)
      metaClass = umlMetaModel.getOwnedType( name )
      if (!profile.getReferenceMetaClasses().contains(metaClass))
        reference = profile.createMetaClassReference(metaClass)
        resource.setID( reference, "MC_REF_" + metaClass.getName() + "_" + name)
      end
    end

    def self.register_extensions(resource_set)
      ext2Factory = ::Java.org.eclipse.emf.ecore.resource.Resource::Factory::Registry::INSTANCE.getExtensionToFactoryMap
      ext2Factory.put( ::Java.org.eclipse.uml2.uml.resource.XMI2UMLResource::FILE_EXTENSION, ::Java.org.eclipse.uml2.uml.resource.UMLResource::Factory::INSTANCE)
      ext2Factory.put( ::Java.org.eclipse.uml2.uml.resource.UMLResource.FILE_EXTENSION, ::Java.org.eclipse.uml2.uml.resource.UMLResource::Factory::INSTANCE)
      ext2Factory.put( "xml", ::Java.org.eclipse.uml2.uml.resource.UMLResource::Factory::INSTANCE)
      resource_set.getPackageRegistry().put( ::Java.org.eclipse.uml2.uml.UMLPackage::eNS_URI, ::Java.org.eclipse.uml2.uml.UMLPackage::eINSTANCE )
    end

    def self.register_pathmaps
      uriClass = ::Java.org.eclipse.emf.common.util.URI
      umlResourceClass = ::Java.org.eclipse.uml2.uml.resource.UMLResource
      class_loader = JRuby.runtime.jruby_class_loader

      umlProfile = "metamodels/UML.metamodel.uml"
      class_loader = ::Java.java.lang.Thread::currentThread.getContextClassLoader
      url = class_loader.getResource(umlProfile) # TODO: This is not working
      baseUrl = url.toString[0, url.toString.length - umlProfile.length]
      baseUri = uriClass.createURI( baseUrl )

      uriMap = ::Java.org.eclipse.emf.ecore.resource.URIConverter::URI_MAP
      uriMap.put( uriClass.createURI( umlResourceClass::LIBRARIES_PATHMAP ),  baseUri.appendSegment("libraries").appendSegment(""))
      uriMap.put( uriClass.createURI( umlResourceClass::METAMODELS_PATHMAP ), baseUri.appendSegment("metamodels").appendSegment(""))
      uriMap.put( uriClass.createURI( umlResourceClass::PROFILES_PATHMAP ),   baseUri.appendSegment("profiles").appendSegment(""))
      uriMap.put( uriClass.createURI( ::Java.org.eclipse.uml2.uml.resource.XMI2UMLResource.UML_METAMODEL_2_1_URI ),
                  uriClass.createURI( url.toString ))
    end
  end
end
