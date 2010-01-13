class Weed::Bucket < Weed::ActiveRecord::Base
  has_many :stats, :class_name => "::Weed::Stats"

  belongs_to :parent, :class_name => "::Weed::Bucket", :foreign_key => "parent_id"
  has_many :children, :class_name => "::Weed::Bucket", :foreign_key => "parent_id"

  # todo: cache this here?!
  def counter
    Weed::Stats.by_total({ :bucket_id => id })
  end

  # todo: bucket groups.
  #  - group by name? ("foo-25")
  #  - group by a field, with id? --> (faster)
  #    - parent/child? (fastest?)
end