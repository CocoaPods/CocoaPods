require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Version do
    it "returns wether or not it's a `bleeding edge' version" do
      version = Version.new('1.2.3')
      version.should.not.be.head
      version.head = true
      version.should.be.head
    end
  end
end
