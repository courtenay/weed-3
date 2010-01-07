class Weed::Stats < Weed::ActiveRecord::Base
  belongs_to :bucket

  def self.hit!(data)
    # need a "inc" like redis/mongo
    affected_rows = update_all(['counter = counter + 1'], data)
    if affected_rows == 0
      Weed::Stats.create! data.merge(:counter => 1)
      affected_rows = 1
    end
    affected_rows 
  end
end