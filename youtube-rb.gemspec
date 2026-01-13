require_relative "lib/youtube-rb/version"

Gem::Specification.new do |spec|
  spec.name          = "youtube-rb"
  spec.version       = YoutubeRb::VERSION
  spec.authors       = ["Maxim Veysgeym"]
  spec.email         = ["qew7777@gmail.com"]

  spec.summary       = "A Ruby library for downloading and extracting YouTube videos and subtitles"
  spec.description   = "A Ruby library inspired by youtube-dl for downloading videos, extracting video segments, and fetching subtitles from YouTube and other video platforms"
  spec.homepage      = "https://github.com/Qew7/youtube-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["source_code_uri"] = "https://github.com/Qew7/youtube-rb"
  spec.metadata["changelog_uri"] = "https://github.com/Qew7/youtube-rb/blob/master/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/Qew7/youtube-rb/issues"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("{lib,bin,spec}/**/*") + %w[README.md LICENSE Rakefile youtube-rb.gemspec]
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.14"
  spec.add_dependency "faraday-retry", "~> 2.4"
  spec.add_dependency "nokogiri", "~> 1.19"
  spec.add_dependency "streamio-ffmpeg", "~> 3.0"
  spec.add_dependency "addressable", "~> 2.8"
  spec.add_dependency "base64", "~> 0.2"

  # Development dependencies
  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.26"
  spec.add_development_dependency "vcr", "~> 6.4"
end
