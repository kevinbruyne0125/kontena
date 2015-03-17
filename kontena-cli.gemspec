# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kontena/cli/version'

Gem::Specification.new do |spec|
  spec.name          = "kontena-cli"
  spec.version       = Kontena::Cli::VERSION
  spec.authors       = ["Lauri Nevala"]
  spec.email         = ["lauri.nevala@gmail.com"]
  spec.summary       = %q{Kontena.io command line tool}
  spec.description   = %q{Kontena.io command line tool}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency 'httpclient', '~> 2.3'
  spec.add_runtime_dependency 'commander'
  spec.add_runtime_dependency 'inifile'
  spec.add_runtime_dependency 'colorize'
end
