require 'rake/tasklib'
require 'rake/testtask'

Rake::TestTask.new :test do |t|
  t.libs << "test"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :environment do
  require 'environment'
end

namespace :db do
  desc "Migrate the database"
  task(:migrate => :environment) do
    module Weed
      Weed::ActiveRecord::Base.logger = Logger.new(STDOUT)
      Weed::ActiveRecord::Base.log_level = :debug
      ActiveRecord::Migration.verbose = true
      Weed::ActiveRecord::Migrator.migrate("db/migrate/weed")
    end
  end
end

task :default => :test
