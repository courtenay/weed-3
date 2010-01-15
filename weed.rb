require 'rubygems'
require 'sinatra/base'
require File.dirname(__FILE__) + '/environment'

module Weed
  class Application < Sinatra::Base
    disable :run, :reload
    enable :logging
    configure :development do
      $stderr.puts "Config"
      Weed::ActiveRecord::Base.connection_args = {  :adapter => 'sqlite3',
       :database =>  File.dirname(__FILE__) + "/db/weed3.development.sqlite3.db"
      }
      Weed::ActiveRecord::Base.establish_connection(Weed::ActiveRecord::Base.connection_args)
      Weed::ActiveRecord::Base.logger = Logger.new "log/development.log"
    end
    configure :test do
      Weed::ActiveRecord::Base.connection_args = {  :adapter => 'sqlite3',
       :database =>  File.dirname(__FILE__) + "/db/weed3.test.sqlite3.db"
      }
      Weed::ActiveRecord::Base.establish_connection(Weed::ActiveRecord::Base.connection_args)
      Weed::ActiveRecord::Base.logger = Logger.new "log/test.log"
    end
    
    Weed::ActiveRecord::Base.establish_connection(Weed::ActiveRecord::Base.connection_args)

    # Load all the models here so we don't namespace conflict
    $LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib")
    $LOAD_PATH.unshift("#{File.dirname(__FILE__)}/lib/weed")
    Dir.glob("#{File.dirname(__FILE__)}/lib/**/*.rb") { |lib| require File.basename(lib, '.*') }

    # Remove trailing slash
    before { request.env['PATH_INFO'].gsub!(/\/$/, '') }

    get "" do
      "Weed!"
    end

    # Record a hit with
    #   { :q => { :bucket_id => 2 }} if you know the bucket id
    #   { :q => { :name => "hits-main" }} to create the bucket or just use its name
    #   { :q => { :bucket_id => 2, :fk => 4 }}
    post "/record" do
      if params[:q][:bucket_id]
        bucket_id = params[:q][:bucket_id]
      elsif params[:q][:name]
        bucket_id = Bucket.find_or_create_by_name(params[:q][:name]).id
        # todo: 404
      else
        raise "Bad params (you can only send q[name] or q[bucket_id])"
      end
      if params[:q][:fk]
        Stats.hit! "cdate" => Time.now, "bucket_id" => bucket_id, "foreign_key_id" => params[:q][:fk]
      else
        Stats.hit! "cdate" => Time.now, "bucket_id" => bucket_id
      end
      # ok
    end

    # import data with :data => date,date,date
    post '/import/:bucket_id' do
      # todo: csv?
      counter = 0
      # todo: move to model/class method?
      params[:data].each do |dates|
        dates = dates.split(",")
        dates.each do |date|
          #$stderr.puts date.inspect
          # date = Date.parse(date)
          stat = Stats.hit! "cdate" => date, "bucket_id" => params[:bucket_id]
          counter += 1
        end
      end
      { "state" => "success", "imported" => counter }.to_json
    end
    
    # todo: test
    post "/import/:bucket_id/:fk_id" do
      counter = 0
      # todo: move to model/class method?
      params[:data].each do |date|
        # todo: delete all stats with fkid
        Stats.hit! "cdate" => date, "bucket_id" => params[:bucket_id], "foreign_key_id" => params[:fk_id]
        counter += 1
      end
      { "state" => "success", "imported" => counter }.to_json
    end

    # import tuples like
    #   :data => ["bucket_id, date", "bucket_id, date"]
    post '/import' do
      # todo: accept json or csv?
      counter = 0
      params[:data].each do |data|
        bucket_id,date = data.split(",")
        Stats.hit! "cdate" => date, "bucket_id" => bucket_id
        counter += 1
      end
      { "state" => "success", "imported" => counter }.to_json
    end

    # todo: auth
    
    get "/buckets" do
      Bucket.all.to_json
    end

    get '/buckets/:name' do
      bucket = Bucket.find_by_name params[:name]
      {"bucket" => { "id" => bucket && bucket.id, "counter" => bucket && bucket.counter,
        "children" => bucket.child_ids
      }}.to_json
    end
    
    # todo: test
    post "/buckets/:parent_id" do
      bucket = Bucket.find params[:parent_id]
      child = bucket.children.find_or_create_by_name params[:name]
      child.id.to_s
    end

    post "/buckets" do
      bucket = Bucket.find_or_create_by_name params[:name]
      bucket.id.to_s
    end
    

    # todo: get /stats/1/day/2009-12-5
    # todo: get /stats/14/month/2009-12
    # todo: get /stats/99/year/2009
    get "/stats" do
      { :count => Stats.count(:conditions => params[:q]) }.to_json
    end
    
    get "/stats/all" do
      if params[:bucket_ids]
        bucket_ids = params[:bucket_ids].map &:to_i
        all = Stats.connection.select_all <<-SQL
          SELECT counter, cdate, buckets.name as name
          FROM   stats left join buckets on buckets.id=stats.bucket_id
          ORDER BY stats.cdate ASC
  SQL
      else
        all = Stats.connection.select_all <<-SQL
          SELECT counter, cdate, buckets.name as name
          FROM   stats left join buckets on buckets.id=stats.bucket_id
          ORDER BY stats.cdate ASC
  SQL
      end
      all.to_json
    end
    
    get "/stats/all/day" do
      (0..120).map do |day|
        date = Date.today - day
        [date, Stats.by_day(date, {})]
      end.to_json
    end
    
    get "/stats/all/debug" do
      erb :"stats/all"
    end
    
    get "/stats/all/date/:date" do
      date = Date.parse params[:date]
      buckets = Weed::Stats.find :all, 
        :conditions => ['cdate BETWEEN ? AND ?', date, date + 1.day], 
        :joins => "left outer join buckets on buckets.id = stats.bucket_id",
        :group => 'stats.bucket_id',
        :select => 'buckets.name AS name, count(stats.id) AS counter'
        
      buckets.to_json
    end
    
    get "/stats/:bucket_id" do
      bucket = Bucket.find params[:bucket_id]
      { :bucket => { :name => bucket.name, :parent_id => bucket.parent_id },
        :count => Stats.by_total({ :bucket_id => params[:bucket_id] }) }.to_json
    end

    get "/stats/:bucket_id/all" do
      bucket = Bucket.find params[:bucket_id]
      # todo: find with sql, don't instantiate
      if bucket.children.any?
        { :bucket => { :name => bucket.name, :parent_id => bucket.parent_id, :children => bucket.children_ids }}.to_json
      else
        { :bucket => { :name => bucket.name, :parent_id => bucket.parent_id },
          :count => Stats.all(:conditions => { :bucket_id => params[:bucket_id] }).map { |s| [s.cdate, s.counter] } }.to_json
      end
    end
    
    get "/stats/:bucket_id/:date" do # hmm. year/month/day?
      bucket = Bucket.find params[:bucket_id]
      { :bucket => { :name => bucket.name, :parent_id => bucket.parent_id },
        :count => Stats.by_day(params[:date], { :bucket_id => params[:bucket_id] }) }.to_json
    end

    get "/stats/:bucket_id/:year/:month" do
      bucket = Bucket.find params[:bucket_id]
      { :bucket => { :name => bucket.name, :parent_id => bucket.parent_id },
        :count => Stats.by_month(params[:year].to_i, params[:month].to_i, { :bucket_id => params[:bucket_id].to_i }) }.to_json
    end

    get "/stats/:bucket_id/:year/:month/:day/week" do
      date = Date.new(params[:year].to_i, params[:month].to_i, params[:day].to_i)
      # todo: i bet we could store this string in the month's data like [1,25,365,126] etc
      (0..6).map do |day|
        Stats.by_day((date - day), { :bucket_id => params[:bucket_id] })
      end.to_json
    end

    #   "/stats/#{bucket5.id}/#{Date.today.year}/#{Date.today.month}/month"
    get "/stats/:bucket_id/:year/:month/month" do
      bucket = Bucket.find params[:bucket_id]
      date = Date.new(params[:year].to_i, params[:month].to_i, 1)
      if bucket.children.empty?
        Stats.by_day_range(date, date + 30, { :bucket_id => params[:bucket_id]}).to_json
        #(0..30).map do |day|
        #  Stats.by_day((date + day), { :bucket_id => params[:bucket_id] })
        #end.to_json
      else
        data = Stats.by_day_range(date, date + 30, { :bucket_id => params[:bucket_id]})
        [{
          "bucket"   => {"name" => bucket.name, "id" => bucket.id},
          "data"     => data,
          "children" => bucket.children.map do |child|
            data = Stats.by_day_range(date, date+30, { :bucket_id => child.id })
             #data = (0..30).map do |day|
             #  Stats.by_day((date + day), { :bucket_id => child.id })
             #end
             {
               "bucket" => {"name" => child.name, "id" => child.id},
                "data"   => data
             }
           end
        }].to_json
      end
    end

    get "/trends/:bucket_id/week/:year/:month/monthly" do
      date = Date.new(params[:year].to_i, params[:month].to_i, 1)
      # todo: i bet we could store this string in the month's data like [1,25,365,126] etc
      (0..6).inject({}) do |hash,current|
        hash["#{date.year}-#{date.month}"] = \
          Stats.by_month(date.year.to_i, date.month.to_i, { :bucket_id => params[:bucket_id] })
        date = (date - 2).beginning_of_month # reliably go back a month
        hash
      end.to_json
    end
    
  end
end