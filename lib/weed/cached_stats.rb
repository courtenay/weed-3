class Weed::CachedStats < Weed::ActiveRecord::Base

  # day, month, year
  def self.by_period(month)
    case period
    when 'month' then -1
    end
  end
  
  def self.override(args)
    count = args.delete(:counter)
    affected_count = update_all ['counter = ?', count], args
    if affected_count == 0
      create args.merge(:counter => count)
    end
  end
end