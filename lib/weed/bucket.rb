class Weed::Bucket < Weed::ActiveRecord::Base
  has_many :stats, :class_name => "::Weed::Stats"

  # todo: cache this here?!
  def counter
    Weed::Stats.by_total({ :bucket_id => id })
  end

  # todo: bucket groups.
  #  - group by name? ("foo-25")
  #  - group by a field, with id? --> (faster)
  #    - parent/child? (fastest?)
end