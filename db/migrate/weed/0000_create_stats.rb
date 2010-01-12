class CreateStats < Weed::ActiveRecord::Migration
  def self.up
    create_table :stats do |f|
      f.integer :bucket_id
      f.integer :counter
      f.datetime :cdate
      f.timestamps
    end
    create_table :cached_stats do |f|
      f.integer :bucket_id
      f.integer :counter
      f.integer :year
      f.integer :month
      f.integer :day
      f.string  :period
      f.timestamps
    end
    create_table :buckets do |f|
      f.string :name
      f.timestamps
      f.index :name
    end
    
  end
end