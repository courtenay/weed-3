require 'rubygems'
require 'active_record'
require 'sinatra/base' unless defined?(Sinatra)

# only tested on 2.3.5
# this file is a huge hack and I don't advise anyone run it at all
module Weed
  module ActiveRecord
#    include ::ActiveRecord
    class Base < ::ActiveRecord::Base
      self.abstract_class = true
      def self.connection_args
        {  :adapter => 'sqlite3',
           :database =>  File.dirname(__FILE__) + '/db/weed3.sqlite3.db'
        }
      end
      establish_connection(connection_args)
    end

    class Migrator < ::ActiveRecord::Migrator
      class << self
        # this probably isn't threadsafe?
        # but then migrations probably it doesn't matter?
        def with_connection(&block)
          old_connection = ActiveRecord::Base.connected? && ActiveRecord::Base.connection.instance_variable_get(:"@config")
          ::ActiveRecord::Base.establish_connection Weed::ActiveRecord::Base.connection_args
          yield
        ensure
          if old_connection
            ::ActiveRecord::Base.establish_connection old_connection
          else
            ::ActiveRecord::Base.remove_connection
          end
        end
        def migrate_with_db(*args)
          with_connection do
            migrate_without_db(*args)
          end
        end
        self.alias_method_chain :migrate, :db
      end
    end
    class Migration < ::ActiveRecord::Migration
    end
  end
end