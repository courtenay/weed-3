class IndexesYo < Weed::ActiveRecord::Migration
  def self.up
    add_index :cached_stats, [:period, :year, :month, :day, :bucket_id]
  end
  def self.down
    remove_index :cached_stats, [:period, :year, :month, :day, :bucket_id]
  end
end