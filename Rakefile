require 'rake'
require 'rake/rdoctask'
require 'rake/gempackagetask'

gem_spec = Gem::Specification.load(File.expand_path('domgen.gemspec', File.dirname(__FILE__)))

task :default => :gem

Rake::GemPackageTask.new(gem_spec).define
