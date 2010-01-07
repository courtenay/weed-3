require 'rubygems'
require 'active_record'
require 'sinatra/base' unless defined?(Sinatra)

module Weed
  module ActiveRecord 
    class Base < ::ActiveRecord::Base
      self.abstract_class = true
      establish_connection(
         :adapter => 'sqlite3',
         :database =>  File.dirname(__FILE__) + '/db/weed3.sqlite3.db'
       )
    end
  end
end

