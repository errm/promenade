lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "promenade/version"

Gem::Specification.new do |spec|
  spec.name          = "promenade"
  spec.version       = Promenade::VERSION
  spec.authors       = ["Ed Robinson"]
  spec.email         = ["edward-robinson@cookpad.com"]

  spec.summary       = "Promenade makes it simple to instrument Ruby apps for prometheus scraping"
  spec.homepage      = "https://github.com/errm/promenade"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.0"

  spec.add_dependency "actionpack"
  spec.add_dependency "activesupport", "> 6.0", "< 9.0"
  spec.add_dependency "prometheus-client-mmap", "~> 1.5"
  spec.add_dependency "rack"
  spec.add_dependency "rackup"
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "climate_control"
  spec.add_development_dependency "rails", "> 3.0", "< 9.0"
  spec.add_development_dependency "raindrops"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rspec-rails", "~> 8.0"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "rubocop-rails"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "simplecov-cobertura"
  spec.metadata["rubygems_mfa_required"] = "true"
end
