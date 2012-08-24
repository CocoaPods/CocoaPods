require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Version do
    it "returns wether or not it's a `bleeding edge' version" do
      version = Version.new('1.2.3')
      version.should.not.be.head
      version.head = true
      version.should.be.head
    end

    it "serializes to and from a string" do
      version = Version.from_string('1.2.3')
      version.to_s.should == '1.2.3'
      version.should.not.be.head

      version = Version.from_string('HEAD based on 1.2.3')
      version.should.be.head
      version.to_s.should == 'HEAD based on 1.2.3'
    end

    it "supports the previous way that a HEAD version was described" do
      version = Version.from_string('HEAD from 1.2.3')
      version.should.be.head
      version.to_s.should == 'HEAD based on 1.2.3'
    end
  end
end
