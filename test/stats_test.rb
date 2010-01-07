require File.dirname(__FILE__)+ '/helper'

class StatsTest < ActiveSupport::TestCase
  fixtures do
    cleanup Weed::Stats
  end

  it "creates a new hit record if one is missing" do
    stat = Weed::Stats.hit!({ :bucket_id => 1, :cdate => Date.today })
    assert_equal 1, stat
  end
  
  it "increments an existing hit record" do
    Weed::Stats.hit!({ :bucket_id => 11, :cdate => Date.today })
    Weed::Stats.hit!({ :bucket_id => 12, :cdate => Date.today })
    Weed::Stats.hit!({ :bucket_id => 12, :cdate => Date.today })
    Weed::Stats.hit!({ :bucket_id => 12, :cdate => Date.today })
    assert_equal 3, Weed::Stats.first(:conditions => { :bucket_id => 12 }).counter
  end
  
  it "calculates daily results" do
    2.times { Weed::Stats.hit!({ :bucket_id => 13, :cdate => Time.now }) }
    3.times { Weed::Stats.hit!({ :bucket_id => 14, :cdate => Time.now }) }
    assert_equal 2, Weed::Stats.by_day(Date.today, { :bucket_id => 13 }), "for #{Date.today} --"
    assert_equal 5, Weed::Stats.by_day(Date.today, {})
  end
  
  it "calculates monthly results" do
    Weed::Stats.delete_all
    Weed::CachedStats.delete_all
    
    2.times { Weed::Stats.hit!({ :bucket_id => 13, :cdate => Date.today - 35}) }
    2.times { Weed::Stats.hit!({ :bucket_id => 13, :cdate => Date.today }) }
    assert_equal 2, Weed::Stats.by_month(Date.today.year, Date.today.month, {})
    # this shouldn't be days in month :/ it should be days up til now
    assert_equal Time.now.day, Weed::CachedStats.count(:conditions => { :year => Date.today.year, :month => Date.today.month })
  end
end
