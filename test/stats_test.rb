require File.dirname(__FILE__)+ '/helper'

class StatsTest < ActiveSupport::TestCase
  fixtures do
    cleanup Weed::Stats
  end

  it "creates a new hit record if one is missing" do
    stat = Weed::Stats.hit!({ :bucket_id => 1 })
    assert_equal 1, stat
  end
  
  it "increments an existing hit record" do
    Weed::Stats.hit!({ :bucket_id => 11 })
    Weed::Stats.hit!({ :bucket_id => 12 })
    Weed::Stats.hit!({ :bucket_id => 12 })
    Weed::Stats.hit!({ :bucket_id => 12 })
    assert_equal 3, Weed::Stats.first(:conditions => { :bucket_id => 12 }).counter
  end
end
