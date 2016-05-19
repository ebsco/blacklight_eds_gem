# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'blacklight_eds/version'

Gem::Specification.new do |spec|
  spec.name          = "blacklight_eds"
  spec.version       = BlacklightEds::VERSION
  spec.authors       = ["EBSCO", "Indiana University"]
  spec.email         = ["efrierson@ebsco.com", "djiao@iu.edu"]

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  end

  spec.summary       = "Gem for EDS API integration with Blacklight5 and up"
  spec.description   = "Gem for EDS API integration with Blacklight5 and up"
  spec.homepage      = "https://github.com/ebsco/blacklight_eds_gem"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "blacklight", ">= 5.8.0", "< 7"
  spec.add_dependency "ebsco-discovery-service-api"
  spec.add_dependency "addressable"
  spec.add_dependency "htmlentities"
  spec.add_dependency "sanitize"
  

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", "~> 10.0"
end
