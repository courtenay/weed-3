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
    # todo: degrade
    results = with_scope(:find => { :conditions => conditions }) do
      Weed::Stats.sum('counter', :conditions => ['(cdate BETWEEN ? AND ?)', date.to_datetime, date.to_datetime + 1.day])
    end
    results = results.is_a?(Hash) ? results.values : [results]
    Weed::CachedStats.override :year => date.year, :month => date.month, :day => date.day, :counter => results[0]
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
            by_day(Date.new(year, month, day), {})
          end
        end # looks like we have all our data
        days = Weed::CachedStats.sum('counter', :conditions => ['month = ?', month])
        # puts "days were: #{days}"
        days
      end
    end
  end
  
  def self.by_year(year, conditions)
    with_scope(:find => {:conditions => conditions }) do
      unless cached = Weed::CachedStats.first(:conditions => ['year = ?'])
        # not found, generate from months
      end
    end    
  end
end