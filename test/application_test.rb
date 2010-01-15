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
    bucket = Weed::Bucket.create :name => "three"

    post '/record', { :q => { "bucket_id" => bucket.id }, :user => 'jimmy-5' }
    get "/stats/#{bucket.id}/#{Date.today.to_s}"
    assert_equal({ "count" => 1, "bucket" => {"name" => "three", "parent_id" => nil} }, JSON.parse(last_response.body))
  end
  
  it "shows monthly stats" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf
    bucket = Weed::Bucket.create :name => "three"
    
    post '/record', { :q => { "bucket_id" => bucket.id }, :user => 'jimmy-5' }
    get "/stats/#{bucket.id}/#{Date.today.year}/#{Date.today.month}"
    assert_equal({ "count" => 1, "bucket" => {"name" => "three", "parent_id" => nil}}, JSON.parse(last_response.body))
  end
  
  it "shows total count with conditions" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf
    bucket3 = Weed::Bucket.create :name => "three"
    bucket4 = Weed::Bucket.create :name => "four"

    post '/record', { :q => { "bucket_id" => bucket4.id }, :user => 'jimmy-5' }
    post '/record', { :q => { "bucket_id" => bucket3.id }, :user => 'jimmy-5' }
    get "/stats/#{bucket3.id}"
    assert_equal({ "count" => 1, "bucket" => {"name" => "three", "parent_id" => nil} }, JSON.parse(last_response.body))
  end

  it "shows stats per day for a week" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf
    bucket5 = Weed::Bucket.create :name => "Update5"
    
    Weed::Stats.hit! :cdate => 7.days.ago, :bucket_id => bucket5.id
    Weed::Stats.hit! :cdate => 6.days.ago, :bucket_id => bucket5.id
    Weed::Stats.hit! :cdate => 6.days.ago, :bucket_id => bucket5.id
    Weed::Stats.hit! :cdate => 5.days.ago, :bucket_id => bucket5.id

    get "/stats/#{bucket5.id}/#{Date.today.year}/#{Date.today.month}/#{Date.today.day}/week"
    assert_equal "[0,0,0,0,0,1,2]", last_response.body
  end

  # This slows the tests down by 3s. ugh.
  it "shows trends per day for a week" do
    Weed::Stats.hit! :cdate => 37.days.ago, :bucket_id => 59
    Weed::Stats.hit! :cdate => 36.days.ago, :bucket_id => 59
    Weed::Stats.hit! :cdate => 36.days.ago, :bucket_id => 59
    Weed::Stats.hit! :cdate => 5.days.ago, :bucket_id => 59

    get "/trends/59/week/#{Date.today.year}/#{Date.today.month}/monthly"
    data = JSON.parse last_response.body
    { "2009-8"  => [0,nil],
      "2009-9"  => [0,nil],
      "2009-10" => [0,nil],
      "2009-11" => [0,nil],
      "2009-12" => [3,nil],
      "2010-1"  => [1,-67],
    }.each do |key,value|
      assert_equal value, data[key], "Unexpected result for #{key}: #{value}"
    end
  end

  it "imports data for a bucket" do
    bucket6 = Weed::Bucket.create :name => "import"

    post "/import/#{bucket6.id}", :data => ["2009-12-5 12:55, 2009-12-5 13:25,2009-12-5 14:56,2009-12-6 00:02,2009-12-18"]
    assert last_response.ok?
    assert_equal({"state"=>"success", "imported"=>5}, JSON.parse(last_response.body))
    
    get "/stats/#{bucket6.id}/2009-12-5"
    assert_equal({"count" => 3,  "bucket" => {"name" => "import", "parent_id" => nil}}, JSON.parse(last_response.body))
  end
  
  # todo: how to do this with params?!
  it "imports data with tuples" do
    Weed::CachedStats.delete_all # wtf
    Weed::Stats.delete_all # wtf
    bucket6 = Weed::Bucket.create :name => "import"
    bucket7 = Weed::Bucket.create :name => "outport"
    
    post "/import", :data => \
      [ "#{bucket6.id},2009-12-5 12:55",
        "#{bucket6.id},2009-12-5 13:25", 
        "#{bucket7.id},2009-12-5 14:56", 
        "#{bucket7.id},2009-12-6 00:02", 
        "#{bucket7.id},2009-12-18"]
    
    assert last_response.ok?
    assert_equal({"state"=>"success", "imported"=>5}, JSON.parse(last_response.body))
    
    get "/stats/#{bucket6.id}/2009-12-5"
    assert_equal({"count" => 2, "bucket" => {"name" => "import", "parent_id" => nil}}, JSON.parse(last_response.body))

    get "/stats/#{bucket7.id}/2009-12-5"
    assert_equal({"count" => 1, "bucket" => {"name" => "outport", "parent_id" => nil}}, JSON.parse(last_response.body))
  end
  
  it "imports data with lists of dates" do
    # todo
  end
  
  it "imports data, clearing existing values" do
    # ugh? wat?
  end
end