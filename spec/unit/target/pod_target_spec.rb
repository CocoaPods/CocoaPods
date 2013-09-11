require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe PodTarget do
    before do
      spec = fixture_spec('banana-lib/BananaLib.podspec')
      @target_definition = Podfile::TargetDefinition.new('Pods', nil)
      @pod_target = PodTarget.new([spec], @target_definition, config.sandbox)
      @pod_target.stubs(:platform).returns(:ios)
    end

    describe "In general" do
      it "returns the target_definition that generated it" do
        @pod_target.target_definition.should == @target_definition
      end

      it "returns its name" do
        @pod_target.name.should == 'Pods-BananaLib'
      end

      it "returns the name of its product" do
        @pod_target.product_name.should == 'libPods-BananaLib.a'
      end

      it "returns the spec consumers for the pod targets" do
        @pod_target.spec_consumers.should.not == nil
      end

      it "returns the root spec" do
        @pod_target.root_spec.name.should == 'BananaLib'
      end

      it "returns the name of the Pod" do
        @pod_target.pod_name.should == 'BananaLib'
      end

      it "returns the name of the Pods on which this target depends" do
        @pod_target.dependencies.should == ["monkey"]
      end

      it "returns the dependencies as root names" do
        dependencies = [stub(:name => 'monkey/subspec')]
        Specification::Consumer.any_instance.stubs(:dependencies).returns(dependencies)
        @pod_target.dependencies.should == ["monkey"]
      end

      it "never includes itself in the dependencies" do
        dependencies = [stub(:name => 'BananaLib/subspec')]
        Specification::Consumer.any_instance.stubs(:dependencies).returns(dependencies)
        @pod_target.dependencies.should == []
      end
    end

  end
end
