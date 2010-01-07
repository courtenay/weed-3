class Weed::CachedStats < Weed::ActiveRecord::Base
  
  def self.override(args)
    # This is really just mongo's "$inc" function
    count = args.delete(:counter)
    affected_count = update_all ['counter = ?', count], args
    if affected_count == 0
      create! args.merge(:counter => count)
    else
      # $stderr.puts "overriding #{args.inspect} with #{count}"
    end
  end
end