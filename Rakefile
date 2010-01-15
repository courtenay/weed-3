require 'rake/tasklib'
require 'rake/testtask'

Rake::TestTask.new :test do |t|
  # RACK_ENV = :test
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
    RACK_ENV = :development unless defined?RACK_ENV
    $stderr.puts "x #{RACK_ENV}"
    
    Weed::ActiveRecord::Base.connection_args = {  :adapter => 'sqlite3',
     :database =>  File.dirname(__FILE__) + "/db/weed3.#{RACK_ENV}.sqlite3.db"
    }
    Weed::ActiveRecord::Base.establish_connection Weed::ActiveRecord::Base.connection_args
    
    module Weed
      Weed::ActiveRecord::Base.logger = Logger.new(STDOUT)
      ActiveRecord::Migration.verbose = true
      Weed::ActiveRecord::Migrator.migrate("db/migrate/weed")
    end
  end
end

task :default => :test
