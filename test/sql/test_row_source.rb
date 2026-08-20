require File.expand_path('../helper', __dir__)
require 'domgen'

class Domgen::Sql::TestRowSource < Domgen::TestCase
  def test_row_source_controls_repository_metadata_and_jpa_defaults
    repository = Domgen.repository(:RowSourceTest) do |r|
      r.enable_facets(:mssql, :jpa)
      r.data_module(:Core) do |m|
        m.entity(:Imported) do |e|
          e.integer(:Id, :primary_key => true)
          e.string(:Name, 20)
          e.sql.index([:Name], :filter => 'Name IS NOT NULL', :defer_creation => true)
        end
        m.entity(:Deployment) do |e|
          e.sql.row_source = :deployment
          e.integer(:Id, :primary_key => true)
        end
      end
    end

    imported = repository.data_module_by_name(:Core).entity_by_name(:Imported)
    deployment = repository.data_module_by_name(:Core).entity_by_name(:Deployment)

    assert_equal :import, imported.sql.row_source
    assert_equal true, imported.jpa.support_create?
    assert_equal true, imported.jpa.support_update?
    assert_equal :deployment, deployment.sql.row_source
    assert_equal false, deployment.jpa.support_create?
    assert_equal false, deployment.jpa.support_update?

    template = File.expand_path('../../lib/domgen/sql/templates/repository.yml.erb', __dir__)
    output = ERB.new(File.read(template), trim_mode: '-').result(binding)
    assert_includes output, "         - name: \"[Core].[tblImported]\"\n" \
                            "           columns:\n" \
                            "             - \"[Id]\"\n" \
                            "             - \"[Name]\"\n" \
                            "           indexes:\n" \
                            "             - \"[PK_Imported]\"\n" \
                            "             - \"[IX_Imported_Name]\"\n"
    assert_includes output, "         - name: \"[Core].[tblDeployment]\"\n" \
                            "           columns:\n" \
                            "             - \"[Id]\"\n" \
                            "           indexes:\n" \
                            "             - \"[PK_Deployment]\"\n" \
                            "           rowSource: deployment\n"
  end

  def test_row_source_rejects_unknown_value
    repository = Domgen.repository(:InvalidRowSourceTest) do |r|
      r.enable_facets(:mssql)
      r.data_module(:Core) do |m|
        m.entity(:Invalid) do |e|
          e.integer(:Id, :primary_key => true)
        end
      end
    end

    entity = repository.data_module_by_name(:Core).entity_by_name(:Invalid)
    error = assert_raises(RuntimeError) do
      entity.sql.row_source = :fixture
    end
    assert_equal 'row_source fixture on Core.Invalid is invalid', error.message
  end
end
