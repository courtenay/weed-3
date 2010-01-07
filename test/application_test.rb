require File.dirname(__FILE__)+ '/helper'

class ApplicationTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  
  fixtures do
    cleanup Weed::Stats
  end
  
  def app
    Weed::Application
  end

  it "runs" do
    get '/'
    assert last_response.ok?, last_response.body
  end
  
  it "records stats" do
    post '/record', { :q => { :bucket_id => 2 }, :user => 'jimmy-5' }
    assert last_response.ok?
    assert_equal 0, last_response.content_length
  end
  
  it "shows stats" do
    get "/stats", { :q => { :bucket_id => 1 } }
    assert last_response.ok?
    assert_equal({ :count => 0 }.to_json, last_response.body)
  end
  
  it "records and shows stats" do
    post '/record', { :q => { :bucket_id => 3 }, :user => 'jimmy-5' }
    get "/stats", { :q => { :bucket_id => 3 } }
    assert_equal({ :count => 1 }.to_json, last_response.body)
  end
end