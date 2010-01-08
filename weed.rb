require 'rubygems'
require 'sinatra/base'
require File.dirname(__FILE__) + '/environment'

module Weed
  class Application < Sinatra::Base
    disable :run, :reload

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
    #   { :q => { :bucket_id => 2 }}
    # 
    post "/record" do
      # valid bucket params are :name
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
    
    # todo: auth

    # todo: get /stats/1/day/2009-12-5
    # todo: get /stats/14/month/2009-12
    # todo: get /stats/99/year/2009
    get "/stats" do
      { :count => Stats.count(:conditions => params[:q]) }.to_json
    end
    
    get "/stats/:bucket_id/day/:date" do # hmm. year/month/day?
      { :count => Stats.by_day(params[:date], { :bucket_id => params[:bucket_id] }) }.to_json
    end

    get "/stats/:bucket_id/month/:year/:month" do
      # todo: daily counts as well as total?
      { :count => Stats.by_month(params[:year].to_i, params[:month].to_i, { :bucket_id => params[:bucket_id].to_i }) }.to_json
    end
    
  end
end