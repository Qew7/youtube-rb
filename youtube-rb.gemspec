Gem::Specification.new do |spec|
  spec.name          = "youtube-rb"
  spec.version       = "0.1.0"
  spec.authors       = ["Maxim Veysgeym"]
  spec.email         = ["qew7777@gmail.com"]

  spec.summary       = "A Ruby gem for working with YouTube"
  spec.description   = "A Ruby library for interacting with YouTube API and functionality"
  spec.homepage      = "https://github.com/Qew7/youtube-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Qew7/youtube-rb"
  spec.metadata["changelog_uri"] = "https://github.com/Qew7/youtube-rb/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("{lib,bin,spec}/**/*") + %w[README.md LICENSE Rakefile youtube-rb.gemspec]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  # spec.add_dependency "example-gem", "~> 1.0"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
