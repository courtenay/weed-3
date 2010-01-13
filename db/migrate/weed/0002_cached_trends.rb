class CachedTrends < Weed::ActiveRecord::Migration
  def self.up
    add_column :cached_stats, :trend, :integer
  end
  def self.down
    remove_column :cached_stats, :trend
  end
end
