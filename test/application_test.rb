require File.dirname(__FILE__)+ '/helper'

class ApplicationTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  
  fixtures do
    cleanup Weed::Stats, Weed::CachedStats
    Weed::Bucket.create :name => "monkeys"
  end
  
  def app
    Weed::Application
  end

  it "runs" do
    get '/'
    assert last_response.ok?, last_response.body
  end
  
  it "records stats with a bucket id" do
    post '/record', { :q => { "bucket_id" => 2 }, :user => 'jimmy-5' }
    assert last_response.ok?
    assert_equal 0, last_response.content_length
  end
  
  it "records stats with params describing a bucket" do
    Weed::Bucket.delete_all

    post '/record', { :q => { 'name' => 'monkeys' }}
    assert last_response.ok?
    assert_equal 0, last_response.content_length
    assert_equal 1, Weed::Bucket.count
    assert_equal 1, Weed::Bucket.last.counter
  end
  
  it "shows stats" do
    get "/stats", { :q => { "bucket_id" => 1 } }
    assert last_response.ok?
    assert_equal({ :count => 0 }.to_json, last_response.body)
  end
  
  it "records and shows stats" do
    post '/record', { :q => { "bucket_id" => 3 }, :user => 'jimmy-5' }
    get "/stats", { :q => { "bucket_id" => 3 } }
    assert_equal({ :count => 1 }.to_json, last_response.body)
  end
  
  it "shows daily stats" do
    # Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf
    post '/record', { :q => { "bucket_id" => 3 }, :user => 'jimmy-5' }
    get "/stats/3/day/#{Date.today.to_s}"
    assert_equal({ :count => 1 }.to_json, last_response.body)
  end
  
  it "shows monthly stats" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf

    post '/record', { :q => { "bucket_id" => 3 }, :user => 'jimmy-5' }
    get "/stats/3/month/#{Date.today.year}/#{Date.today.month}"
    assert_equal({ :count => 1 }.to_json, last_response.body)
  end

  it "shows stats per day for a week" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf

    Weed::Stats.hit! :cdate => 7.days.ago, :bucket_id => 5
    Weed::Stats.hit! :cdate => 6.days.ago, :bucket_id => 5
    Weed::Stats.hit! :cdate => 6.days.ago, :bucket_id => 5
    Weed::Stats.hit! :cdate => 5.days.ago, :bucket_id => 5

    get "/stats/5/week/#{Date.today.year}/#{Date.today.month}/#{Date.today.day}/daily"
    assert_equal "[0,0,0,0,0,1,2]", last_response.body
  end
end