# -*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "protocol_buffers_require/version"

Gem::Specification.new do |gem|
  gem.name          = "ruby-protocol-buffers-require"
  gem.version       = ProtocolBuffersRequire::GEM_VERSION
  gem.authors       = ["Peter Edge"]
  gem.email         = ["peter@locality.com"]
  gem.summary       = %{ProtocolBuffersRequire}
  gem.description   = %{ProtocolBuffersRequire for Ruby}
  gem.homepage      = "https://github.com/centzy/ruby-protocol-buffers-require"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "ruby-protocol-buffers"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "yard"
end
