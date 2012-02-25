require File.expand_path('../../spec_helper', __FILE__)
require 'tmpdir'

TMP_POD_ROOT = ROOT + "tmp" + "podroot"

describe Pod::Sandbox do

  before do 
    @sandbox = Pod::Sandbox.new(TMP_POD_ROOT)
  end
  
  after do
    @sandbox.implode
  end
  
  it "automatically creates the TMP_POD_ROOT if it doesn't exist" do
    File.directory?(TMP_POD_ROOT).should.be.true
  end
  
  it "deletes the entire root directory on implode" do
    @sandbox.implode
    File.directory?(TMP_POD_ROOT).should.be.false
    FileUtils.mkdir(TMP_POD_ROOT) # put it back again
  end
  
end
