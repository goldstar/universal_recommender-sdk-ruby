# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'universal_recommender/version'

Gem::Specification.new do |spec|
  spec.name          = 'universal_recommender'
  spec.version       = UniversalRecommender::VERSION
  spec.authors       = ['Matthew Peychich']
  spec.email         = ['mpeychich@goldstar.com']
  spec.homepage      = 'https://github.com/goldstar/universal_recommender-sdk-ruby'
  spec.summary       = 'Universal Recommender Ruby SDK'
  spec.description   = <<-EOF
The Universal Recommender (UR) is a PredictionIO engine providing collaborative
filtering based on the Correlated Cross-Occurence (CCO) algorithm. This gem lays
the groundwork for integrating your Ruby application with Universal Recommender.
EOF

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'predictionio', '~> 0.12.1'
  spec.add_runtime_dependency 'activesupport', '> 4'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
