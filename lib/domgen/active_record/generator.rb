module Domgen
  module Generator
    module ActiveRecord
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ruby]
    end

    def self.define_active_record_templates
      [
        Template.new(ActiveRecord::FACETS, :entity, "#{ActiveRecord::TEMPLATE_DIRECTORY}/entity.rb.erb", 'ruby/#{entity.ruby.filename}.rb', [Domgen::Ruby::Helper])
      ]
    end
  end
end
