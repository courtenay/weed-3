class Weed::Bucket < Weed::ActiveRecord::Base
  has_many :stats, :class_name => "::Weed::Stats"
  
  def counter
    Weed::Stats.by_total({ :bucket_id => id })
  end

end