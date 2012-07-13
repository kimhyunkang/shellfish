require 'rubygems'
require 'rspec/core/rake_task'

task :default => [:spec]

RSpec::Core::RakeTask.new(:spec) do |t|
  t.ruby_opts = ['-Ilib']
end
