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
  
  it "creates a bucket" do
    post "/buckets", :name => "foo-bar"
    assert last_response.ok?
    bucket = Weed::Bucket.find_by_name("foo-bar")
    assert_equal bucket.id.to_s, last_response.body
  end

  # only supports 'name' right now
  it "records stats with params describing a bucket" do
    Weed::Bucket.delete_all

    post '/record', { :q => { 'name' => 'monkeys' }}
    assert last_response.ok?
    assert_equal 0, last_response.content_length
    assert_equal 1, Weed::Bucket.count
    assert_equal 1, Weed::Bucket.last.counter
  end
  
  it "finds bucket id based on name" do
    bucket = Weed::Bucket.create! :name => "bananas"
    get '/buckets/bananas'
    assert last_response.ok?
    assert_equal({"bucket" => { "id" => bucket.id, "counter" => nil }}.to_json, last_response.body)
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
  
  it "shows total count with conditions" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf

    post '/record', { :q => { "bucket_id" => 4 }, :user => 'jimmy-5' }
    post '/record', { :q => { "bucket_id" => 3 }, :user => 'jimmy-5' }
    get "/stats/3"
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

  it "imports data" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf

    post "/import/6", :data => ["2009-12-5 12:55", "2009-12-5 13:25", "2009-12-5 14:56", "2009-12-6 00:02", "2009-12-18"]
    assert last_response.ok?
    assert_equal({:state=>"success", "imported"=>5}.to_json, last_response.body)
    
    get "/stats/6/day/2009-12-5"
    assert_equal({"count" => 3}.to_json, last_response.body)
  end
  
  it "imports data, clearing existing values" do
    # ugh? wat?
  end
end