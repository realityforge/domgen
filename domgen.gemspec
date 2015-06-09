# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'domgen/version'

Gem::Specification.new do |s|
  s.name               = %q{domgen}
  s.version            = Domgen::VERSION
  s.platform           = Gem::Platform::RUBY

  s.authors            = ['Peter Donald']
  s.email              = %q{peter@realityforge.org}

  s.homepage           = %q{https://github.com/realityforge/domgen}
  s.summary            = %q{A tool to generates code from a simple domain model.}
  s.description        = %q{A tool to generates code from a simple domain model.}

  s.rubyforge_project  = %q{domgen}

  s.files              = `git ls-files`.split("\n")
  s.test_files         = `git ls-files -- {spec}/*`.split("\n")
  s.executables        = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.default_executable = []
  s.require_paths      = %w(lib)

  s.has_rdoc           = false
  s.rdoc_options       = %w(--line-numbers --inline-source --title domgen)
end
