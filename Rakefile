# frozen_string_literal: true
require 'rubocop/rake_task'
require_relative 'config/application'

task spec: %i(rubocop spec)

Rails.application.load_tasks

task :rubocop do
  RuboCop::RakeTask.new do |task|
    task.requires << 'rubocop-rspec'
  end
end
