require File.dirname(__FILE__)+ '/helper'

class BucketTest < ActiveSupport::TestCase
  #fixtures do
  #end

  it "knows about its genealogy" do
    bucket_parent = Weed::Bucket.create :name => "Animals"
    bucket_child  = Weed::Bucket.create :name => "Monkeys", :parent => bucket_parent

    assert_equal [bucket_child], bucket_parent.children
  end
end