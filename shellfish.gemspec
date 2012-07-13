Gem::Specification.new do |spec|
  spec.name = 'shellfish'
  spec.version = '0.0.1'
  spec.date = '2012-07-11'
  spec.summary = 'Shellfish'
  spec.description = 'Remote shell environment using Net::SSH 2'
  spec.authors = ['Kim HyunKang']
  spec.email = 'kimhyunkang@gmail.com'
  spec.files = ['lib/shellfish.rb']
  spec.homepage = 'https://github.com/kimhyunkang/shellfish'
  spec.platform = Gem::Platform::RUBY
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 1.9'

  spec.add_dependency 'net-ssh', '~> 2.5.2'
  spec.add_dependency 'highline', '~> 1.6.13'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '> 2.0.0'

  spec.has_rdoc = true
  spec.extra_rdoc_files = ['README.md']
end
