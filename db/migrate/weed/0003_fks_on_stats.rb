class FksOnStats < Weed::ActiveRecord::Migration
  def self.up
    add_column :stats, :foreign_id, :integer
    add_column :stats, :foreign_type, :string
  end
  def self.down
    remove_column :stats, :foreign_type
    remove_column :stats, :foreign_id
  end
end
