class CachedStatsNeedDates < Weed::ActiveRecord::Migration
  def self.up
    add_column :cached_stats, :cdate, :datetime
  end
  
  def self.down
    remove_column :cached_stats, :cdate
  end
end
 