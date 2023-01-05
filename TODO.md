## TODO

### General

* Generate documentation indicating the template groups, contained artifacts, facet list, facet configurations
  etc from metadata attached to code.
* Display WARNING when generators overlap and when generators produce no artifacts - at least if warning mode is enabled.
* When we define the artifacts in the model files, we should also be able to define the "template_group" and
  "artifact type" (ie, main/java vs test/java vs main/resources etc). This would allow us to remove the need
  for generator.rb files.
* Make it possible to define a model check that defines the dependency requirements
  between schemas. i.e. Entity can not be referenced by anyone. Template can reference
  Entity but not Overtimes etc.
* Support constants in relationship_constraints
* Fix xmi generation: fix existing enumeration/service generation, add message generation
* Introduce the "uses" metadata for service that can refer to entities (a.k.a DAOs) and other services. Use this to
  generate abstract service with required dependencies and update the uml generated.
* Add state machine (based on rails gem or erlang library?)
* Add validation annotations; @NotNull, @Pattern, @Past
* Add unique constraints in jpa ala - http://lucasterdev.altervista.org/wordpress/2012/07/28/unique-constraint-validation-part-1/
* Use javax.xml.bind.annotation.XmlSeeAlso in inheritance hierarchies ala Exception/Entity
* Generate an error when you disable a facet (i.e. json) but it is referenced by a different element
  with a facet that requires the presence of the disabled facet (i.e. the gwt_rpc facet requires the
  json facet if a struct is referenced from a gwt_rpc enabled method). Also consider disable facets
  on referencing elements. i.e. if a facet is disabled on a struct then disable the facet on all the
  parameter/attribute/etc instances that reference struct.
* Change struct method in domgen to derive name from type and allow override of name, thus eliminating need
  for the first parameter in most cases.
* Rename messages in domgen to events as that is more reflective of actual intent. (i.e. Application internal signalling).
* Add the ability for method parameters to reference events. Currently if a method receives an event it has to be defined like `m.parameter(:Message, 'iris.rose.server.event.EventCountChanged')` where we should be able to do `m.message(:EventCountChanged)`
* Remove BaseTaggableElement and move tags to being attributes inside mssql facet to reflect that their only use is extended attributes.
* Exceptions that contain references should have a constructor that takes the entity. This would improve the type safety of the application.

### Services

* Convert service layer to using json+http services.
* Add Validation annotations to all service interfaces, including DAO/repositories
* JWS: Add ability to document wsdl
* Swaggerize new json service API. Possibly wait until OpenAPI is established? http://swagger.io/

### Sync

* Complete the bulk sync action when don't care about replication or in memory activity
* Convert Sync code to use the generated views for joins against non-final entities

### Replicant

* Consider incremental changes. (Or may need both Full and partial updates
  recorded so different messages are routed to different listeners?)
* Merge multiple update channels into on replicant session. i.e. How to merge AppConfig into ODS stream?
* Merge identical filters in output format.

### Sql

* Add UPDATE([X]) guard around generated SetOnce violation checking in triggers for MsSql.  Investigate similar scenarios.

### JPA

* Mark jpa setters as package access ... even if entity has to be visible in other packages. This forces mutations to occur within the package.
* Mark jpa repository update methods as package access if we can?
