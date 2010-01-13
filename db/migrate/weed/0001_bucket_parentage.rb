class BucketParentage < Weed::ActiveRecord::Migration
  def self.up
    add_column :buckets, :parent_id, :integer
    add_index :buckets, :parent_id
  end
  def self.down
    remove_column :buckets, :parent_id
  end
end
