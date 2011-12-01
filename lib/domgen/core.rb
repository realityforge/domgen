module Domgen
  Logger = ::Logger.new(STDOUT)
  Logger.level = ::Logger::WARN
  Logger.datetime_format = ''

  def self.error(message)
    Logger.error(message)
    raise message
  end

  class BaseElement
    def initialize(options = {})
      self.options = options
      yield self if block_given?
    end

    def options=(options)
      options.each_pair do |k, v|
        keys = k.to_s.split('.')
        target = self
        keys[0, keys.length - 1].each do |target_accessor_key|
          target = target.send target_accessor_key.to_sym
        end
        target.send "#{keys.last}=", v
      end
    end

    protected

    def error(message)
      Domgen.error(message)
    end
  end

  class BaseTaggableElement < BaseElement
    attr_writer :tags

    def tags
      @tags ||= {}
    end

    def description(value)
      tags[:Description] = value
    end

    def tag_as_html(key)
      value = tags[key]
      if value
        require 'maruku' unless defined?(::Maruku)
        ::Maruku.new(value).to_html
      else
        nil
      end
    end
  end

  def self.ParentedElement(parent_key, pre_config_code = '')
    type = Class.new(BaseTaggableElement)
    code = <<-RUBY
    attr_accessor :#{parent_key}

    def initialize(#{parent_key}, options = {}, &block)
      @#{parent_key} = #{parent_key}
    #{pre_config_code}
      super(options, &block)
    end
    RUBY
    type.class_eval(code)
    type
  end
end