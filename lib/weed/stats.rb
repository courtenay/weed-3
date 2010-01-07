require 'active_support'
require 'weed/cached_stats'
class Weed::Stats < Weed::ActiveRecord::Base
  belongs_to :bucket

  # Records a hit
  def self.hit!(data)
    raise "Bad params in #{data.keys.inspect}" unless data.keys == ["bucket_id", "cdate"] || data.keys == [:bucket_id, :cdate] || data.keys == [:cdate, :bucket_id] || data.keys == ["cdate", "bucket_id"]
    # need a "inc" like redis/mongo
    affected_rows = update_all(['counter = counter + 1'], data)
    if affected_rows == 0
      Weed::Stats.create! data.merge(:counter => 1)
      affected_rows = 1
    end
    affected_rows 
  end
  
  def self.by_day(date, conditions)
    date = Date.parse(date) if (date.is_a?(String))
    results = nil # ugh
    Weed::Stats.with_scope(:find => { :conditions => conditions }) do
      results = Weed::Stats.sum('counter', :conditions => ['(cdate BETWEEN ? AND ?)', date.to_datetime, date.to_datetime + 1.day])
      results = results.is_a?(Hash) ? results.values : [results]
      Weed::CachedStats.override(conditions.merge({:year => date.year, :month => date.month, :day => date.day, :counter => results[0], :period => "day"}))
    end
    results[0]
  end

  def self.by_month(year, month, conditions)
    Weed::CachedStats.with_scope(:find => {:conditions => conditions }) do
      unless cached = Weed::CachedStats.first(:conditions => ['period = ? AND year = ? AND month = ?', 'month', year, month])
        days = Weed::CachedStats.count(:conditions => ['period = ? AND year = ? AND month = ?', 'day', year, month])
        today = Date.today
        max = (month == today.month && year == today.year) ? today.day : Time.days_in_month(month)
        if count < max
          # not enough stats for the observed month, please regenerate them
          (1..max).each do |day|
            by_day(Date.new(year, month, day), conditions)
          end
        end # looks like we have all our data
        days = Weed::CachedStats.sum('counter', :conditions => ['(period = ? AND year = ? AND month = ?)', 'day', year, month])
        # cache the year
        # Weed::CachedStats.override :year => year, :period => 'year', :counter => days
        Weed::CachedStats.override(conditions.merge({:year => year, :month => 'month', :period => 'month', :counter => days}))
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
        Weed::CachedStats.override(({:year => year, :period => 'year', :counter => sum}))
        Weed::CachedStats.sum('counter', :conditions => ['period = ? AND year = ?', 'year', year])
      else
        cached
      end
    end    
  end
end