# frozen_string_literal: true
require_relative 'config/application'

task spec: %i(rubocop spec)

if Rails.env.development? || Rails.env.test?
  require 'rubocop/rake_task'
  task :rubocop do
    RuboCop::RakeTask.new do |task|
      task.requires << 'rubocop-rspec'
    end
  end
end

Rails.application.load_tasks
