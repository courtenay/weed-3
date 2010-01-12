require 'active_support'
require 'weed/cached_stats'
class Weed::Stats < Weed::ActiveRecord::Base
  belongs_to :bucket

  # Records a hit
  def self.hit!(data)
    # this is horrible
    raise "Bad params in #{data.keys.inspect}" unless data.keys == ["bucket_id", "cdate"] || data.keys == [:bucket_id, :cdate] || data.keys == [:cdate, :bucket_id] || data.keys == ["cdate", "bucket_id"]
    # need a "inc" like redis/mongo
    # todo: different update strategies
    # either: 
    #   a) when making a hit, update all the other cached rows (current month, year)
    #   b) just run the row caching periodically
    # this depends on the speed at which our update job runs and the priority for read/write speed.
    affected_rows = update_all(['counter = counter + 1'], data)
    if affected_rows == 0
      Weed::Stats.create! data.merge(:counter => 1)
      affected_rows = 1
    end
    affected_rows 
  end
  
  def self.by_day(date, conditions)
    date = Date.parse(date) if (date.is_a?(String))
    Weed::CachedStats.with_scope(:find => {:conditions => conditions}) do
      unless cached = Weed::CachedStats.first(:conditions => ['period = ? AND year = ? AND month = ? AND day = ?', 'day', date.year, date.month, date.day])
        day = Weed::Stats.with_scope(:find => { :conditions => conditions }) do
          Weed::Stats.sum "counter", :conditions => ['cdate BETWEEN ? AND ?', date, date + 1.day]
        end
      # day = results.is_a?(Hash) ? results.values : [results] # maybe not needed?
        Weed::CachedStats.override conditions.merge({:year => date.year, :month => date.month, :day => date.day, :period => 'day', :counter => day})
        day
      else
        cached.counter
      end
    end
  end
  
  def self.find_by_day(date, conditions)
    Weed::Stats.with_scope(:find => { :conditions => conditions }) do
      Weed::Stats.find :all, :conditions => ['(cdate BETWEEN ? AND ?)', date.to_datetime, date.to_datetime + 1.day]
    end
  end

  def self.by_month(year, month, conditions)
    Weed::CachedStats.with_scope(:find => {:conditions => conditions }) do
      unless cached = Weed::CachedStats.first(:conditions => ['period = ? AND year = ? AND month = ?', 'month', year, month])
        days = Weed::CachedStats.count(:conditions => ['period = ? AND year = ? AND month = ?', 'day', year, month])
        today = Date.today
        max = (month == today.month && year == today.year) ? today.day : Time.days_in_month(month)
        if days < max
          # not enough stats for the observed month, please regenerate them
          (1..max).each do |day|
            by_day(Date.new(year, month, day), conditions)
          end
        end # looks like we have all our data
        days = Weed::CachedStats.sum('counter', :conditions => ['(period = ? AND year = ? AND month = ?)', 'day', year, month])
        # cache the year
        # Weed::CachedStats.override :year => year, :period => 'year', :counter => days
        Weed::CachedStats.override(conditions.merge({:year => year, :month => month, :period => 'month', :counter => days}))
        days
      else
        cached.counter 
      end
    end
  end
  
  def self.by_year(year, conditions)
    Weed::CachedStats.with_scope(:find => {:conditions => conditions }) do
      unless cached = Weed::CachedStats.first(:conditions => ['period = ? AND year = ?', 'year', year])
        # not found, generate from months
        max = (year == Date.today.year) ? Date.today.month : 12
        sum = 0
        (1..max).each do |month|
          sum += by_month(year, month, conditions)
        end
        Weed::CachedStats.override(conditions.merge({:year => year, :period => 'year', :counter => sum}))
        # Weed::CachedStats.sum('counter', :conditions => ['period = ? AND year = ?', 'year', year])
        sum
      else
        # raise "not implemented!"
        cached.counter
      end
    end    
  end
  
  def self.by_total(conditions)
    Weed::CachedStats.with_scope(:find => {:conditions => conditions}) do
      unless cached = Weed::CachedStats.first(:conditions => ['period = ?', 'total'])
        # regenerate total
        # first find the full range of stats
        oldest = Weed::Stats.first(:conditions => conditions)
        newest = Weed::Stats.first(:conditions => conditions, :order => "cdate desc")
        sum = 0
        if oldest && newest
          (oldest.cdate.year..newest.cdate.year).each do |year|
            sum += by_year(year, conditions)
          end
          Weed::CachedStats.override(conditions.merge({:period => 'total', :counter => sum}))
          # Weed::CachedStats.sum('counter', :conditions => ['period = ?', 'total'])
          sum
        end
      else
        cached.counter
      end
    end
  end
end