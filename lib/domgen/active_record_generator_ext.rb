module Domgen
  module Generator
    def self.define_active_record_templates(template_set)
      template_set.per_object_type << Template.new('active_record/model', '#{object_type.ruby.filename}.rb', 'ruby')
    end
  end
end
