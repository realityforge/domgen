module Domgen
  module Generator
    def self.define_active_record_templates
      template_dir = "#{File.dirname(__FILE__)}/templates"
      [
        Template.new(:object_type,
                     "#{template_dir}/model.erb",
                     'ruby/#{object_type.ruby.filename}.rb',
                     [Domgen::Ruby::Helper])
      ]
    end
  end
end
