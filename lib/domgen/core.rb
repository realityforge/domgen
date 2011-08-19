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
        self.send "#{k}=", v
      end
    end

    protected

    def error(message)
      Domgen.error(message)
    end
  end
end