require File.expand_path('../../spec_helper', __FILE__)

describe 'Xcodeproj::Project' do
  before do
    @project = Xcodeproj::Project.new
  end

  def find_object(conditions)
    @project.objects_hash.select do |_, object|
      (conditions.keys - object.keys).empty? && object.values_at(*conditions.keys) == conditions.values
    end.first
  end

  it "adds a group to the `Pods' group" do
    group = @project.add_pod_group('JSONKit')
    @project.pods.childReferences.should.include group.uuid
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
    @project.targets.first.buildPhases.should.include phase
  end
  
  shared "for any platform" do
    it "adds a Debug and Release build configuration" do
      @project.build_configurations.count.should == 2
      @project.build_configurations.map(&:name).sort.should == %w{Debug Release}.sort
    end
  end
  
  describe "for the :ios platform" do
    before do
      @project = Xcodeproj::Project.for_platform(Pod::Platform.new(:ios))
    end
    
    behaves_like "for any platform"
    
    it "sets VALIDATE_PRODUCT to YES for the Release configuration" do
      @project.build_configuration("Release").buildSettings["VALIDATE_PRODUCT"].should == "YES"
    end
  end
  
  describe "for the :ios platform with a deployment target" do
    it "sets ARCHS to 'armv6 armv7' for both configurations if the deployment target is less than 4.3" do
      @project = Xcodeproj::Project.for_platform(Pod::Platform.new(:ios, :deployment_target => "4.0"))
      @project.build_configuration("Debug").buildSettings["ARCHS"].should == "armv6 armv7"
      @project.build_configuration("Release").buildSettings["ARCHS"].should == "armv6 armv7"
      
      @project = Xcodeproj::Project.for_platform(Pod::Platform.new(:ios, :deployment_target => "4.1"))
      @project.build_configuration("Debug").buildSettings["ARCHS"].should == "armv6 armv7"
      @project.build_configuration("Release").buildSettings["ARCHS"].should == "armv6 armv7"
      
      @project = Xcodeproj::Project.for_platform(Pod::Platform.new(:ios, :deployment_target => "4.2"))
      @project.build_configuration("Debug").buildSettings["ARCHS"].should == "armv6 armv7"
      @project.build_configuration("Release").buildSettings["ARCHS"].should == "armv6 armv7"
    end
    
    it "uses standard ARCHs if deployment target is 4.3 or above" do
      @project = Xcodeproj::Project.for_platform(Pod::Platform.new(:ios, :deployment_target => "4.3"))
      @project.build_configuration("Debug").buildSettings["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      @project.build_configuration("Release").buildSettings["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      
      @project = Xcodeproj::Project.for_platform(Pod::Platform.new(:ios, :deployment_target => "4.4"))
      @project.build_configuration("Debug").buildSettings["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      @project.build_configuration("Release").buildSettings["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
    end
  end
end
