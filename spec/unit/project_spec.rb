require File.expand_path('../../spec_helper', __FILE__)

describe 'Pod::Project' do
  before do
    @project = Pod::Project.new
  end

  def find_object(conditions)
    @project.objects_hash.select do |_, object|
      (conditions.keys - object.keys).empty? && object.values_at(*conditions.keys) == conditions.values
    end.first
  end

  it "adds a group to the `Pods' group" do
    group = @project.add_pod_group('JSONKit')
    @project.pods.child_references.should.include group.uuid
    find_object({
      'isa' => 'PBXGroup',
      'name' => 'JSONKit',
      'sourceTree' => '<group>',
      'children' => []
    }).should.not == nil
  end

  it "creates a copy build header phase which will copy headers to a specified path" do
    @project.targets.new
    phase = @project.targets.first.copy_files_build_phases.new_pod_dir("SomePod", "Path/To/Source")
    find_object({
      'isa' => 'PBXCopyFilesBuildPhase',
      'dstPath' => 'Pods/Path/To/Source',
      'name' => 'Copy SomePod Public Headers'
    }).should.not == nil
    @project.targets.first.build_phases.should.include phase
  end

  it "adds build configurations named after every configuration across all of the user's projects" do
    @project.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'Test' => :debug, 'AppStore' => :release }
    @project.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
  end

  it "adds build configurations named after every configuration across all of the user's projects to a target" do
    @project.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'Test' => :debug, 'AppStore' => :release }
    target = @project.add_pod_target('SomeTarget', Pod::Platform.ios)
    target.build_settings('Test')["VALIDATE_PRODUCT"].should == nil
    target.build_settings('AppStore')["VALIDATE_PRODUCT"].should == "YES"
  end

  describe "concerning its :ios targets" do
    it "sets VALIDATE_PRODUCT to YES for the Release configuration" do
      target = Pod::Project.new.add_pod_target('Pods', Pod::Platform.ios)
      target.build_settings('Release')["VALIDATE_PRODUCT"].should == "YES"
    end
  end

  describe "concerning its :ios targets with a deployment target" do
    before do
      @project = Pod::Project.new
    end

    it "sets ARCHS to 'armv6 armv7' for both configurations if the deployment target is less than 4.3" do
      target = @project.add_pod_target('Pods', Pod::Platform.new(:ios, :deployment_target => "4.0"))
      target.build_settings('Debug')["ARCHS"].should == "armv6 armv7"
      target.build_settings('Release')["ARCHS"].should == "armv6 armv7"

      target = @project.add_pod_target('Pods', Pod::Platform.new(:ios, :deployment_target => "4.1"))
      target.build_settings('Debug')["ARCHS"].should == "armv6 armv7"
      target.build_settings('Release')["ARCHS"].should == "armv6 armv7"

      target = @project.add_pod_target('Pods', Pod::Platform.new(:ios, :deployment_target => "4.2"))
      target.build_settings('Debug')["ARCHS"].should == "armv6 armv7"
      target.build_settings('Release')["ARCHS"].should == "armv6 armv7"
    end

    it "uses standard ARCHs if deployment target is 4.3 or above" do
      target = @project.add_pod_target('Pods', Pod::Platform.new(:ios, :deployment_target => "4.3"))
      target.build_settings('Debug')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      target.build_settings('Release')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"

      target = @project.add_pod_target('Pods', Pod::Platform.new(:ios, :deployment_target => "4.4"))
      target.build_settings('Debug')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      target.build_settings('Release')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
    end

    it "sets IPHONEOS_DEPLOYMENT_TARGET for both configurations" do
      target = @project.add_pod_target('Pods', Pod::Platform.new(:ios))
      target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "4.3"
      target.build_settings('Release')["IPHONEOS_DEPLOYMENT_TARGET"].should == "4.3"

      target = @project.add_pod_target('Pods', Pod::Platform.new(:ios, :deployment_target => "4.0"))
      target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "4.0"
      target.build_settings('Release')["IPHONEOS_DEPLOYMENT_TARGET"].should == "4.0"
    end
  end
end
