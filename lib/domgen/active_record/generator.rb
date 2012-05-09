module Domgen
  module Generator
    module ActiveRecord
      TEMPLATE_DIRECTORY = "#{File.dirname(__FILE__)}/templates"
      FACETS = [:ruby]
    end
  end
end
Domgen.template_set(:active_record) do |template_set|
  template_set.template(Domgen::Generator::ActiveRecord::FACETS,
                        :entity,
                        "#{Domgen::Generator::ActiveRecord::TEMPLATE_DIRECTORY}/entity.rb.erb",
                        'main/ruby/#{entity.ruby.filename}.rb',
                        [Domgen::Ruby::Helper])
end
