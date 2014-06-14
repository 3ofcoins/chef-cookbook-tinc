# rubocop:disable Style/HashSyntax

require 'bundler/setup'

desc 'Run tests from Strainerfile'
task :strain do
  require 'strainer'
  Thor::Base.shell = Strainer::Shell
  Strainer::Shell.enable_colors = $stdout.tty?
  Strainer::Runner.new([],
                       strainer_file: 'Strainerfile',
                       debug: !!ENV['DEBUG']).run!
end

task :test => :strain
task :default => :test

task :pry do
  require 'pry'
  binding.pry                   # rubocop:disable Lint/Debugger
end
