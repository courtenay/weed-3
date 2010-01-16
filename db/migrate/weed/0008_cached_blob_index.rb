class CachedBlobIndex < Weed::ActiveRecord::Migration
  def self.up
    add_index :cached_blobs, [:bucket_id, :start_date, :end_date]
  end
  def self.down
    remove_index :cached_blobs, [:bucket_id, :start_date, :end_date]
  end
end