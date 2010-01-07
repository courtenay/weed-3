require File.dirname(__FILE__)+ '/helper'

class ApplicationTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  
  fixtures do
  end
  
  def app
    Weed::Application
  end

  def test_it_runs
    get '/'
    assert last_response.ok?, last_response.body
  end
  
end