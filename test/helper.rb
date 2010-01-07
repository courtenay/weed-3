ENV['RACK_ENV'] = 'test'

# Add all the code in vendor to the load path
Dir["#{File.dirname(__FILE__)}/../vendor/**"].map do |dir|
  $LOAD_PATH.unshift File.directory?(lib = "#{dir}/lib") ? lib : dir
end

require 'rubygems'
require 'active_record'
# require 'activesupport'
require 'active_support/test_case' # dubious
require 'weed'
require 'test/unit'
require 'rack/test'
require 'machinist'
require 'vendor/context/lib/context'
# require 'action_controller/test_process'
# require 'action_controller/integration'
# require 'context_on_crack'
# require 'ruby-debug'
# require 'rr'
# require 'facebooker/rails/test_helpers'
require 'faker'
require File.dirname(__FILE__) + '/blueprints'

class Weed::Application
  set :environment, :test
end

class Test::Unit::TestCase
  # include Rack::Test::Methods
  
  def app
    Weed::Application # your application class
  end

#    include RR::Adapters::RRMethods

#  before do
#    ActiveRecord::Base.connection.increment_open_transactions
#    ActiveRecord::Base.connection.begin_db_transaction
#  end
#
#  after do
#    ActiveRecord::Base.connection.decrement_open_transactions
#    ActiveRecord::Base.connection.rollback_db_transaction
#    ActiveRecord::Base.verify_active_connections!
#  end

  def self.fixtures(options = {}, &block)
    fixture = FixtureRunner.new(block, options)
    before(:all) { fixture.run(self) }
  end

  class FixtureRunner
    class << self
      attr_accessor :skipped_ivars
    end

    self.skipped_ivars = Set.new(["@test_passed", "@values", "@method_name"])

    attr_reader :proc, :values

    # :skip_transaction => true
    def initialize(proc, options = {})
      @proc    = proc
      @options = options
    end

    def run(binding)
      if !already_run?
        binding.instance_variables.each do |ivar|
          next if self.class.skipped_ivars.include?(ivar)
          instance_variable_set ivar, binding.instance_variable_get(ivar)
        end
        existing = instance_variables
        action   = lambda { instance_eval &@proc }
        @options[:skip_transaction] ? action.call : transaction(&action)
        store_values_except existing
      end
      values = @values
      reload_method = method(:reload_or_use)
      binding.instance_eval do
        values.each do |key, value|
          instance_variable_set key, reload_method.call(value)
        end
      end
    end

    def store_values_except(existing)
      @values = {}
      (instance_variables - existing).each do |ivar|
        @values[ivar] = instance_variable_get(ivar)
      end
    end

    def cleanup(*klasses)
      klasses.each { |k| k.delete_all }
    end

    def already_run?
      !@values.blank?
    end

    def transaction
      Weed::ActiveRecord::Base.transaction { yield }
    end

    def reload_or_use(value)
      value.class.respond_to?(:find) ? value.class.find_by_id(value.id) : value
    end
  end

end