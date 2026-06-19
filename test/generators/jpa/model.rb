class TestFacetExtension
  module MyHelperModule
  end

  class << self
    include Domgen::Generators::ArtifactDSL

    def template_set_container
      Domgen::TestCase::TestTemplateSetContainer
    end

    def target_key
      :entity
    end

    def facet_key
      :jpa
    end

    def define_artifacts1
      file_artifact(:models, :mytemplate, 'main/java/#{entity.qualified_name}.java')
    end

    def define_artifacts2
      file_artifact(:models, :rubytemplate, 'main/java/#{entity.qualified_name}.java')
    end

    def define_artifacts3
      file_artifact(:models,
                    :mytemplate,
                    'main/java/#{entity.qualified_name}.java',
                    :facets => [:ee],
                    :helpers => [MyHelperModule],
                    :guard => 'entity.jpa.good?')
    end

    def define_artifacts4
      file_artifact(:models, :mytemplate, 'main/java/#{entity.qualified_name}.java')
    end

    def define_artifacts5
      file_artifact(:models, :mytemplate, 'main/java/#{entity.qualified_name}.java')
      file_artifact(:qa_models, :mytemplate, 'test/java/#{entity.qualified_name}.java')
      file_artifact(:qa_models, :rubytemplate, 'main/java/#{entity.qualified_name}.java')
    end

    def define_artifacts6
      file_artifact(:models, :mytemplate, 'main/java/#{entity.qualified_name}.java', :bad_option => true)
    end

    def define_artifacts7
      java_artifact(:models, :mytemplate)
    end

    def define_artifacts8
      java_artifact(:models, :mytemplate, :artifact_category => :test)
    end

    def define_artifacts9
      java_artifact(:models, :mytemplate, :artifact_category => :main)
    end
  end
end
