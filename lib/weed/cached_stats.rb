class Weed::CachedStats < Weed::ActiveRecord::Base
  belongs_to :bucket
  
  def self.override(args)
    # This is really just mongo's "$inc" function
    count = args.delete(:counter)
    trend = args.delete(:trend)
    affected_count = update_all ['counter = ? AND trend = ?', count, trend], args
    if affected_count == 0
      create! args.merge(:counter => count)
    else
      # $stderr.puts "overriding #{args.inspect} with #{count} and #{trend}"
    end
  end
end