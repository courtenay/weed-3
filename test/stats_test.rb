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
    assert_equal 2, Weed::Stats.by_day(Date.today, { :bucket_id => 13 })
    assert_equal 3, Weed::Stats.by_day(Date.today, { :bucket_id => 14 })
    assert_equal 5, Weed::Stats.by_day(Date.today, { })
  end
  
  it "calculates monthly results" do
    Weed::Stats.delete_all
    Weed::CachedStats.delete_all
    
    2.times { Weed::Stats.hit!({ :bucket_id => 13, :cdate => Date.today - 35.days}) }
    2.times { Weed::Stats.hit!({ :bucket_id => 13, :cdate => Date.today }) }
    assert_equal 2, Weed::Stats.by_month(Date.today.year, Date.today.month, { :bucket_id => 13 })
    assert_equal 2, Weed::Stats.by_month(Date.today.year, Date.today.month, {}) # no conditions
    # this shouldn't be days in month :/ it should be days up til now
    assert_equal Time.now.day, Weed::CachedStats.count(:conditions => { :year => Date.today.year, :month => Date.today.month, :period => "day", :bucket_id => 13 })
  end

  it "calculates yearly results" do
    Weed::Stats.delete_all
    Weed::CachedStats.delete_all
    
    date = Date.new(2010, 1, 4)
    2.times { Weed::Stats.hit!({ :bucket_id => 15, :cdate => date - 35}) }
    2.times { Weed::Stats.hit!({ :bucket_id => 15, :cdate => date }) }
    # assert_equal 2, Weed::Stats.by_month(Date.today.year, Date.today.month, {})
    # this shouldn't be days in month :/ it should be days up til now

    # generate year stats
    Weed::Stats.by_year date.year, { :bucket_id => 15 }
    # count the buckets
    assert_equal 1, Weed::CachedStats.count(:conditions => { :year => date.year, :period => "year" })
    # count the hits
    assert_equal 2, Weed::CachedStats.sum('counter', :conditions => { :year => date.year, :period => "year", :bucket_id => 15 })
    assert_equal 0, Weed::CachedStats.sum('counter', :conditions => { :year => date.year, :period => "year", :bucket_id => 13 })
  end
  
  context "with trends" do
    it "gives a trend" do
      date = Date.new(2010, 1, 4)
      2.times { Weed::Stats.hit!({ :bucket_id => 15, :cdate => date - 40}) }
      2.times { Weed::Stats.hit!({ :bucket_id => 15, :cdate => date - 20}) }
      2.times { Weed::Stats.hit!({ :bucket_id => 15, :cdate => date }) }
    
      stats = Weed::Stats.by_month date.year, date.month, { :bucket_id => 15 }, :trend
      assert_equal [2, nil], stats
    end
    
    it "shows a rising trend" do
      date = Date.new(2010, 1, 4)
      2.times { Weed::Stats.hit!({ :bucket_id => 125, :cdate => date - 20}) }
      3.times { Weed::Stats.hit!({ :bucket_id => 125, :cdate => date }) }
    
      stats = Weed::Stats.by_month date.year, date.month, { :bucket_id => 125 }, :trend
      assert_equal [3, 50], stats
    end
    
    it "shows a falling trend" do
      date = Date.new(2010, 1, 4)
      4.times { Weed::Stats.hit!({ :bucket_id => 135, :cdate => date - 20}) }
      2.times { Weed::Stats.hit!({ :bucket_id => 135, :cdate => date }) }
    
      stats = Weed::Stats.by_month date.year, date.month, { :bucket_id => 135 }, :trend
      assert_equal [2, -50], stats
    end
  end
  
  # this is slow as fuck
  # it "calculates total results" do
  #   # provide a range of year data
  #   oldest_stat = Weed::Stats.hit!({:bucket_id => 5, :cdate => 3.year.ago })
  #   newest_stat = Weed::Stats.hit!({:bucket_id => 5, :cdate => 1.day.ago })
  # 
  #   Weed::CachedStats.create :year => 3.years.ago.year, :period => "year"
  #   Weed::CachedStats.create :year => 2.years.ago.year, :period => "year"
  #   
  #   assert_equal 2, Weed::Stats.by_total(:bucket_id => 5)
  # end
  
  # todo: test number of queries for a cached result
  # todo: test num of queries for a non cached result
end
