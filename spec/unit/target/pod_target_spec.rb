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
    end

    describe "Support files" do
      it "returns the absolute path of the xcconfig file" do
        @pod_target.xcconfig_path.to_s.should.include 'Pods/Pods-BananaLib.xcconfig'
      end

      it "returns the absolute path of the target header file" do
        @pod_target.target_environment_header_path.to_s.should.include 'Pods/Pods-environment.h'
      end

      it "returns the absolute path of the prefix header file" do
        @pod_target.prefix_header_path.to_s.should.include 'Pods/Pods-BananaLib-prefix.pch'
      end

      it "returns the absolute path of the bridge support file" do
        @pod_target.bridge_support_path.to_s.should.include 'Pods/Pods-BananaLib.bridgesupport'
      end

      it "returns the absolute path of the public and private xcconfig files" do
        @pod_target.xcconfig_path.to_s.should.include 'Pods/Pods-BananaLib.xcconfig'
        @pod_target.xcconfig_private_path.to_s.should.include 'Pods/Pods-BananaLib-Private.xcconfig'
      end
    end

  end
end
