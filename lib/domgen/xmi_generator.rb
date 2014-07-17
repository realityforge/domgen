#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Domgen
  module Xmi
    class GenerateXMITask
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
              Domgen::Xmi.generate_xmi(self.repository_key, self.filename)
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

    def self.get_static_field_value(classname, field)
      ::Java.java.lang.Thread.currentThread.getContextClassLoader.loadClass(classname).getField(field).get(nil)
    end

    def self.generate_xmi(repository_key, filename)
      repository = Domgen.repository_by_name(repository_key)

      output_file = ::Java.java.io.File.new(filename).getAbsolutePath()

      registry = get_static_field_value('org.eclipse.emf.ecore.resource.Resource$Factory$Registry', 'INSTANCE')
      umlResource = get_static_field_value('org.eclipse.uml2.uml.resource.UMLResource$Factory', 'INSTANCE')
      ak_NONE_LITERAL = get_static_field_value('org.eclipse.uml2.uml.AggregationKind', 'NONE_LITERAL')
      ak_SHARED_LITERAL = get_static_field_value('org.eclipse.uml2.uml.AggregationKind', 'SHARED_LITERAL')
      ak_COMPOSITE_LITERAL = get_static_field_value('org.eclipse.uml2.uml.AggregationKind', 'COMPOSITE_LITERAL')
      lit_UNLIMITED = get_static_field_value('org.eclipse.uml2.uml.LiteralUnlimitedNatural', 'UNLIMITED')

      registry.getExtensionToFactoryMap().put(File.extname(output_file).gsub('.', ''), umlResource)

      model = ::Java.org.eclipse.uml2.uml.UMLFactory.eINSTANCE.createModel()
      model.setName(repository.name.to_s)

      output_uri = ::Java.org.eclipse.emf.common.util.URI.createFileURI(output_file)
      puts "Creating XMI for repository #{repository_key} at #{output_file}"
      resource = ::Java.org.eclipse.emf.ecore.resource.impl.ResourceSetImpl.new.create_resource(output_uri)
      resource.getContents().add(model)
      name(resource, model, repository)
      describe(model, repository)

      # As we process the schema set, we put all the packages that we discover inside this array
      # This is a map between package names and EMF package classes
      packages = {}

      # As we process the schema set, we put all the primitive types that we discover inside this map
      # This is a map between DB types to EMF primitive types
      primitive_types = {}

      # A map from fully qualified class names to EMF classes
      name_2_emf_map = {}

      # Phase 1: Package, primitive type, and enumeration type discovery.
      # Primitive types will be added to the top-level model but enumeration types
      # will be added to the package they belong to.
      #
      repository.data_modules.each do |data_module|
        package = model.createNestedPackage(data_module.name.to_s)
        name(resource, package, data_module)
        describe(package, data_module)

        packages[data_module.name] = package

        data_module.enumerations.each do |enumeration|
          enum = package.createOwnedEnumeration(enumeration.name.to_s)
          enumeration.values.each do |enum_literal|
            literal = enum.create_owned_literal(enum_literal)
            resource.setID(literal, "#{enumeration.qualified_name}.#{enum_literal}")
          end
          name(resource, enum, enumeration)
          describe(enum, enumeration)
          name_2_emf_map[enumeration.qualified_name] = enum
        end

        data_module.entities.each do |entity|
          entity.attributes.each do |attribute|
            if !attribute.reference?
              pn = primitive_name(attribute.attribute_type)
              if !primitive_types[pn]
                primitive_type = model.createOwnedPrimitiveType(pn)
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
          clazz = package.createOwnedClass(entity.name.to_s, false)
          name(resource, clazz, entity)
          describe(clazz, entity)
          name_2_emf_map[entity.qualified_name] ||= clazz
          entity.attributes.each do |attribute|
            define_attribute(resource, name_2_emf_map, primitive_types, clazz, attribute)
          end
        end
      end

      repository.data_modules.each do |data_module|
        data_module.structs.each do |struct|
          package = packages[data_module.name]
          clazz = package.createOwnedClass(struct.name.to_s, false)
          name(resource, clazz, struct)
          describe(clazz, struct)
          name_2_emf_map[struct.qualified_name] ||= clazz

          # Creating EMF attributes for each field
          struct.fields.each do |field|
            define_attribute(resource, name_2_emf_map, primitive_types, clazz, field)
          end
        end
      end

      # Phase 3: Association building. In this phase, we process the schema set and create EMF associations
      # corresponding to the references defined in it.
      repository.data_modules.each do |data_module|
        data_module.entities.each do |entity|
          entity.attributes.select { |attribute| attribute.reference? }.each do |attribute|
            end1 = name_2_emf_map[attribute.entity.qualified_name]
            end2 = name_2_emf_map[attribute.referenced_entity.qualified_name]
            name = attribute.name == attribute.referenced_entity.name ? "" : attribute.name.to_s

            aggregation_kind = ak_NONE_LITERAL
            aggregation_kind = ak_SHARED_LITERAL if attribute.inverse.relationship_kind == :aggregation
            aggregation_kind = ak_COMPOSITE_LITERAL if attribute.inverse.relationship_kind == :composition

            createAssociation = end1.getClass().getMethods().find{|m| m.getName() == "createAssociation" }

            emf_association = createAssociation.invoke(end1,
                                                       [true,
                                                     aggregation_kind,
                                                     name,
                                                     attribute.nullable? ? 0 : 1,
                                                     1,
                                                     end2,
                                                     attribute.inverse.traversable?,
                                                     ak_NONE_LITERAL,
                                                     '',
                                                     0,
                                                     attribute.inverse.multiplicity == :many ? lit_UNLIMITED : 1])
            resource.setID(emf_association, attribute.qualified_name.to_s + ".Assoc")
            describe(emf_association, attribute)
          end
        end
      end

      # Phase 4: Service creation. In this phase, we process the repository and create a class or each service.
      repository.data_modules.each do |data_module|
        data_module.services.each do |service|
          package = packages[data_module.name]
          clazz = package.createOwnedClass(service.name.to_s, false)
          name(resource, clazz, service)
          describe(clazz, service)
          name_2_emf_map[service.qualified_name] ||= clazz

          service.methods.each do |method|
            names = ::Java.org.eclipse.emf.common.util.BasicEList.new(method.parameters.size)
            types = ::Java.org.eclipse.emf.common.util.BasicEList.new(method.parameters.size)

            method.parameters.each do |characteristic|
              names.add(characteristic.name.to_s)
              types.add(characteristic_type(name_2_emf_map, primitive_types, characteristic))
            end

            operation = if method.return_value.return_type != :void
              emf_type = characteristic_type(name_2_emf_map, primitive_types, method.return_value)
              clazz.createOwnedOperation(method.name.to_s, names, types, emf_type)
            else
              clazz.createOwnedOperation(method.name.to_s, names, types)
            end
            name(resource, operation, method)
            describe(operation, method)
          end
        end
      end

      # Phase 5: Message creation.
      repository.data_modules.each do |data_module|
        package = packages[data_module.name]
        data_module.messages.each do |message|
          msg_class_name = "#{message.name}Message"
          emf_class = package.createOwnedClass(msg_class_name, false)
          name(resource, emf_class, message)
          describe(emf_class, message)
          name_2_emf_map[message.qualified_name.to_s] ||= emf_class

          message.parameters.each do |parameter|
            define_attribute(resource, name_2_emf_map, primitive_types, emf_class, parameter)
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
      Buildr.artifacts(::Domgen::Xmi.dependencies).each do |artifact|
        artifact.invoke
        ::Java.classpath << artifact.to_s
      end
    end

    def self.dependencies
      [
        'org.eclipse.uml2:org.eclipse.uml2.uml:jar:3.1.0.v201006071150',
        'org.eclipse.uml2:org.eclipse.uml2.uml.resources:jar:3.1.0.v201005031530',
        'org.eclipse.uml2:org.eclipse.uml2.common:jar:1.5.0.v201005031530',
        'org.eclipse.emf:org.eclipse.emf.ecore:jar:2.6.0.v20100614-1136',
        'org.eclipse.emf:org.eclipse.emf.common:jar:2.6.0.v20100614-1136',
        'org.eclipse.emf:org.eclipse.emf.mapping.ecore2xml:jar:2.5.0.v20100521-1847',
        'org.eclipse.emf:org.eclipse.emf.ecore.xmi:jar:2.5.0.v20100521-1846',
      ]
    end

    def self.primitive_name(attribute_type)
      return "string" if attribute_type == :text
      return "int" if attribute_type == :integer
      return "long" if attribute_type == :long
      return attribute_type.to_s
    end

    def self.define_attribute(resource, name_2_emf_map, primitive_types, emf_clazz, characteristic)
      emf_type = characteristic_type(name_2_emf_map, primitive_types, characteristic)
      emf_attr = emf_clazz.createOwnedAttribute(characteristic.name.to_s, emf_type)
      name(resource, emf_attr, characteristic)
      describe(emf_attr, characteristic)
    end

    def self.characteristic_type(name_2_emf_map, primitive_types, characteristic)
      if characteristic.enumeration?
        name_2_emf_map[characteristic.enumeration.qualified_name]
      elsif characteristic.struct?
        name_2_emf_map[characteristic.referenced_struct.qualified_name]
      else
        characteristic_type =
          characteristic.reference? ? characteristic.referenced_entity.primary_key.characteristic_type_key : characteristic.characteristic_type_key
        primitive_types[primitive_name(characteristic_type)]
      end
    end

    def self.name(resource, emf_element, domgen_element)
      resource.setID(emf_element, domgen_element.qualified_name.to_s)
    end

    def self.describe(emf_element, domgen_element)
      description = domgen_element.tag_as_html(:Description)
      if description
        emf_element.createOwnedComment().setBody(description)
      end
    end
  end
end
