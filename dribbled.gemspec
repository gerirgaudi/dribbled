# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'dribbled/version'
require 'dribbled/about'

Gem::Specification.new do |s|
  s.name                      = Dribbled::ME.to_s
  s.version                   = Dribbled::VERSION
  s.platform                  = Gem::Platform::RUBY
  s.authors                   = "Gerardo López-Fernádez"
  s.email                     = 'gerir@evernote.com'
  s.homepage                  = 'https://github.com/evernote/ops-dribbled'
  s.summary                   = "DRBD tool"
  s.description               = "Provides a wrapper around DRBD to gather information and perform monitoring checks"
  s.license                   = "Apache License, Version 2.0"
  s.required_rubygems_version = ">= 1.3.5"

  s.add_dependency('xml-simple')
  s.add_dependency('log4r')
  s.add_dependency('senedsa', '>= 0.2.9')

  s.files        = Dir['lib/**/*.rb'] + Dir['bin/*'] + %w(LICENSE README.md)
  s.executables  = %w(dribbled check_drbd)
  s.require_path = 'lib'
end
