require 'rubygems'
require 'sinatra/base'
require File.dirname(__FILE__) + '/environment'

module Weed
  class Application < Sinatra::Base
    disable :run, :reload
    enable :logging

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
    post "/record" do
      if params[:q][:bucket_id]
        bucket_id = params[:q][:bucket_id]
      elsif params[:q][:name]
        bucket_id = Bucket.find_or_create_by_name(params[:q][:name]).id
        # todo: 404
      else
        raise "Bad params (you can only send q[name] or q[bucket_id])"
      end
      # todo: generate bucket id from params[:q]
      Stats.hit! "cdate" => Time.now, "bucket_id" => bucket_id
      # ok
    end
    
    post '/import/:bucket_id' do
      # todo: csv?
      counter = 0
      # todo: move to model/class method?
      params[:data].each do |date|
        Stats.hit! "cdate" => date, "bucket_id" => params[:bucket_id]
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
    
    get '/buckets/:name' do
      bucket = Bucket.find_by_name params[:name]
      {"bucket" => { "id" => bucket.id, "counter" => bucket.counter }}.to_json
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
          SELECT counter, created_at AS date
          FROM   stats
          ORDER BY created_at ASC
  SQL
      else
        all = Stats.connection.select_all <<-SQL
          SELECT counter, created_at AS date
          FROM   stats
          ORDER BY created_at ASC
  SQL
      end
      all.to_json
    end
    
    get "/stats/all/day" do
      (0..60).map do |day|
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
      { :count => Stats.by_total({ :bucket_id => params[:bucket_id] }) }.to_json
    end

    get "/stats/:bucket_id/all" do
      # todo: find with sql, don't instantiate
      { :count => Stats.all(:conditions => { :bucket_id => params[:bucket_id] }).map { |s| [s.created_at, s.counter] } }.to_json
    end
    
    get "/stats/:bucket_id/day/:date" do # hmm. year/month/day?
      { :count => Stats.by_day(params[:date], { :bucket_id => params[:bucket_id] }) }.to_json
    end

    get "/stats/:bucket_id/month/:year/:month" do
      { :count => Stats.by_month(params[:year].to_i, params[:month].to_i, { :bucket_id => params[:bucket_id].to_i }) }.to_json
    end

    get "/stats/:bucket_id/week/:year/:month/:day/daily" do
      date = Date.new(params[:year].to_i, params[:month].to_i, params[:day].to_i)
      # todo: i bet we could store this string in the month's data like [1,25,365,126] etc
      (0..6).map do |day|
        Stats.by_day((date - day).to_date, { :bucket_id => params[:bucket_id] })
      end.to_json
    end
    
  end
end