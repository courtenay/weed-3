class UpgradeDailyCachedStats < Weed::ActiveRecord::Migration
    class Weed::CachedStats < Weed::ActiveRecord::Base
    set_table_name "cached_stats"
  end
  def self.up
    ::Weed::CachedStats.find_in_batches(:conditions => ['period = ?', 'day']) do |stats|
      stats.each do |cs|
        cs.cdate = Date.new(cs.year, cs.month, cs.day)
        cs.save
      end
    end
  end
  
  def self.down
  end
end
