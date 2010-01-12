class Weed::Bucket < Weed::ActiveRecord::Base
  has_many :stats, :class_name => "::Weed::Stats"
  
  # todo: cache this here?!
  def counter
    Weed::Stats.by_total({ :bucket_id => id })
  end

end