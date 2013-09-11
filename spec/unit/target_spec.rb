require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Target do
    before do
      @sut = Target.new('Pods', nil)
      @child = Target.new('BananaLib', @sut)
    end

    #-------------------------------------------------------------------------#

    describe "In general" do
      it "adds itself to the children of the parent" do
        @sut.children.should == [@child]
      end

      it "returns the root" do
        @sut.root.should == @sut
        @child.root.should == @sut
      end

      it "returns whether it is root" do
        @sut.should.be.root
        @child.should.not.be.root
      end

      it "returns its name" do
        @sut.name.should == 'Pods'
        @child.name.should == 'Pods-BananaLib'
      end

      it "returns the name of its product" do
        @sut.product_name.should == 'libPods.a'
      end
    end

    #-------------------------------------------------------------------------#

    describe "Specs" do
      before do
        spec = fixture_spec('banana-lib/BananaLib.podspec')
        @sut.specs = [spec]
        @sut.platform = Platform.ios
      end

      it "returns the specs of the Pods used by this aggregate target" do
        @sut.specs.map(&:name).should == ["BananaLib"]
      end

      it "returns the spec consumers for the pod targets" do
        consumers = @sut.spec_consumers.map { |consumer| [consumer.spec.name, consumer.platform_name ] }
        consumers.should == [["BananaLib", :ios]]
      end

        it "returns the root spec" do
          @sut.root_spec.name.should == 'BananaLib'
        end

        it "returns the name of the Pod" do
          @sut.pod_name.should == 'BananaLib'
        end

        #----------------------------------------#

        describe "#dependencies" do
          it "returns the name of the Pods on which this target depends" do
            @sut.dependencies.should == ["monkey"]
          end

          it "returns the dependencies as root names" do
            dependencies = [stub(:name => 'monkey/subspec')]
            Specification::Consumer.any_instance.stubs(:dependencies).returns(dependencies)
            @sut.dependencies.should == ["monkey"]
          end

          it "never includes itself in the dependencies" do
            dependencies = [stub(:name => 'BananaLib/subspec')]
            Specification::Consumer.any_instance.stubs(:dependencies).returns(dependencies)
            @sut.dependencies.should == []
          end
        end

        #----------------------------------------#

    end

    #-------------------------------------------------------------------------#

    describe "Aggregate" do
    end

    #-------------------------------------------------------------------------#

    describe "Pod" do
    end

    #-------------------------------------------------------------------------#

  end
end

