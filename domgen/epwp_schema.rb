require "#{File.dirname(__FILE__)}/domgen/domgen.rb"

Domgen::Logger.level = Logger::DEBUG

schema_set = Domgen::SchemaSet.new do |ss|
  ss.define_schema("iris") do |s|
    s.java.package = 'epwp.iris'
    s.sql.schema = 'Resource'


    s.define_object_type(:Task, :abstract => true) do |t|
      t.integer(:ID, :primary_key => true)
      t.string(:Name, 50)
    end

    s.define_object_type(:SpecificTask, :extends => :Task, :final => false) do |t|
      t.string(:STName, 50)
    end

    s.define_object_type(:ManagementProject, :extends => :SpecificTask) do |t|
      t.string(:MPName, 50)
    end


    s.define_object_type(:DeployableUnitType, :abstract => true) do |t|
      t.integer(:ID, :primary_key => true)
      t.string(:Name, 50)
    end

    s.define_object_type(:CrewType, :extends => :DeployableUnitType) do |t|
      t.string(:CrewName, 50)
    end

    s.define_object_type(:PhysicalUnitType, :extends => :DeployableUnitType) do |t|
      t.string(:PhysicalUnitName, 50)
    end

    s.define_object_type(:DeployableUnit, :abstract => true) do |t|
      t.integer(:ID, :primary_key => true)
      t.reference(:DeployableUnitType, :name => :IsOfType, :immutable => true, :abstract => true)
      t.string(:Name, 50)
      t.reference(:ManagementProject, :name => :IsMemberOfPool, :inverse_relationship_name => :PoolMember, :nullable => true) do |a|
        a.iris.inverse_sorter = "epwp.iris.sorter.DeployableUnitSorter"
      end
      t.reference(:ManagementProject, :name => :IsBasedAt, :inverse_relationship_name => :BaseMember)
    end

    s.define_object_type(:PhysicalUnit, :extends => :DeployableUnit) do |t|
      t.integer(:Foo)
      t.reference(:PhysicalUnitType, :name => :IsOfType, :immutable => true)
    end

    s.define_object_type(:Crew, :extends => :DeployableUnit) do |t|
      t.integer(:Bar)
      t.reference(:CrewType, :name => :IsOfType, :immutable => true)
    end
  end
end

Domgen::Generator.generate(schema_set, 'target/generated', Domgen::Generator::DEFAULT_ARTIFACTS + [:iris])
