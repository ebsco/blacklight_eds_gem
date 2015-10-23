require "bundler/gem_tasks"
require 'rspec/core/rake_task'

desc 'Run specs'
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = '-r spec_helper.rb'
end
