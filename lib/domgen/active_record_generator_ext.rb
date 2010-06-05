module Domgen
  module Generator
    def self.define_active_record_templates
      [
          Template.new(:object_type, 'active_record/model', 'ruby/#{object_type.ruby.filename}.rb')
      ]
    end
  end
end
