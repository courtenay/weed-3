class CreateStats < Weed::ActiveRecord::Migration
  def self.up
    create_table :stats do |f|
      f.integer :bucket_id
      f.integer :counter
      f.timestamps
    end
    create_table :facts do |f|
      f.integer :bucket_id
      f.datetime :end_date
      f.string   :period
    end
    create_table :buckets do |f|
      f.string :name
      f.timestamps
    end
  end
end