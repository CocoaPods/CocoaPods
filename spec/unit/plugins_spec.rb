require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Plugins do
    before do
      @sut = Pod::Plugins
    end

    it "allows to register a block for a hook with a given name" do
      @sut.register(:post_install) do |options|
      end
      @sut.registrations[:post_install].count.should == 1
      @sut.registrations[:post_install].first.class.should == Proc
    end

    it "raise if no block is given in the registration process" do
      should.raise ArgumentError do
        @sut.register(:post_install)
      end
    end

    it "allows to run the hooks " do
      @sut.register(:post_install) do |options|
        true.should.be.true
      end
      @sut.run(:post_install, {})
    end

    it "doesn't raises if no plugins have been registered" do
      should.not.raise do
        @sut.run(:post_install, {})
      end
    end


    it "doesn't raises if no plugins for a specific hook have been registered" do
      @sut.register(:post_install) do |options|
        true.should.be.true
      end
      should.not.raise do
        @sut.run(:pre_install, {})
      end
    end
  end
end

