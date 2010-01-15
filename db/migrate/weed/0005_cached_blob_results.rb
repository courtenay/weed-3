class CachedBlobResults < Weed::ActiveRecord::Migration
  def self.up
    create_table :cached_blobs, :force => true do |t|
      t.text :counters
      t.integer :bucket_id
      t.datetime :start_date
      t.datetime :end_date
      t.index [:bucket_id, :year, :month]
      t.timestamps
    end
  end
  def self.down
    drop_table :cached_blob
  end
end