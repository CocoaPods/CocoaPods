require File.expand_path('../../spec_helper', __FILE__)

describe Pod::Project do
  describe "In general" do
    before do
      @project = Pod::Project.new(config.sandbox)
    end

    it "returns the sandbox used for the project" do
      @project.sandbox.should == config.sandbox
    end

    it "creates the support file group on initialization" do
      @project.support_files_group.name.should == 'Targets Support Files'
    end

    it "returns its path" do
      @project.path.should == config.sandbox.project_path
    end

    it "returns the `Pods` group" do
      @project.pods.name.should == 'Pods'
    end

    it "returns the `Local Pods` group" do
      @project.local_pods.name.should == 'Local Pods'
    end

    it "adds a group for a specification" do
      group = @project.add_spec_group('JSONKit', @project.pods)
      @project.pods.children.should.include?(group)
      g = @project['Pods/JSONKit']
      g.name.should == 'JSONKit'
      g.children.should.be.empty?
    end

    it "namespaces subspecs in groups" do
      group = @project.add_spec_group('JSONKit/Subspec', @project.pods)
      @project.pods.groups.find { |g| g.name == 'JSONKit' }.children.should.include?(group)
      g = @project['Pods/JSONKit/Subspec']
      g.name.should == 'Subspec'
      g.children.should.be.empty?
    end

    it "adds the Podfile configured as a Ruby file" do
      @project.add_podfile(config.project_podfile)
      f = @project['Podfile']
      f.name.should == 'Podfile'
      f.source_tree.should == 'SOURCE_ROOT'
      f.xc_language_specification_identifier.should == 'xcode.lang.ruby'
      f.path.should == '../Podfile'
    end

    it "adds build configurations named after every configuration across all of the user's projects" do
      @project.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'Test' => :debug, 'AppStore' => :release }
      @project.build_configurations.map(&:name).sort.should == %w{ AppStore Debug Release Test }
    end
  end

  describe "Libraries" do
    before do
      @project = Pod::Project.new(config.sandbox)
      podfile = Pod::Podfile.new do
        platform :ios, '4.3'
        pod 'JSONKit'
      end
      @target_definition = podfile.target_definitions.values.first
    end

    it "adds build configurations named after every configuration across all of the user's projects to a target" do
      @project.user_build_configurations = { 'Debug' => :debug, 'Release' => :release, 'Test' => :debug, 'AppStore' => :release }
      library = @project.add_pod_library(@target_definition)
      target = library.target
      target.build_settings('Test')["VALIDATE_PRODUCT"].should == nil
      target.build_settings('AppStore')["VALIDATE_PRODUCT"].should == "YES"
    end

    it "sets ARCHS to 'armv6 armv7' for both configurations if the deployment target is less than 4.3 for iOS targets" do
      @target_definition.platform = Pod::Platform.new(:ios, '4.2')
      library = @project.add_pod_library(@target_definition)
      target = library.target
      target.build_settings('Debug')["ARCHS"].should == "armv6 armv7"
      target.build_settings('Release')["ARCHS"].should == "armv6 armv7"
    end

    before do
      @lib = @project.add_pod_library(@target_definition)
      @target = @lib.target
    end

    it "uses standard ARCHs if deployment target is 4.3 or above" do
      @target.build_settings('Debug')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
      @target.build_settings('Release')["ARCHS"].should == "$(ARCHS_STANDARD_32_BIT)"
    end

    it "sets VALIDATE_PRODUCT to YES for the Release configuration for iOS targets" do
      @lib.target.build_settings('Release')["VALIDATE_PRODUCT"].should == "YES"
    end

    it "sets IPHONEOS_DEPLOYMENT_TARGET for iOS targets" do
      @target.build_settings('Debug')["IPHONEOS_DEPLOYMENT_TARGET"].should == "4.3"
      @target.build_settings('Release')["IPHONEOS_DEPLOYMENT_TARGET"].should == "4.3"
    end

    it "returns the added libraries" do
      @project.libraries.should == [ @lib ]
    end
  end
end

#-----------------------------------------------------------------------------#

describe Pod::Project::Library do
  describe "In general" do
    before do
      project = Pod::Project.new(config.sandbox)
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'JSONKit'
      end
      @target_definition = podfile.target_definitions.values.first
      @lib = project.add_pod_library(@target_definition)
    end

    it "returns the target_definition that generated it" do
      @lib.target_definition.should == @target_definition
    end

    it "returns it target in the Pods project" do
      @lib.target.name.should == 'Pods'
    end

    it "returns the label of the target definition" do
      @lib.label.should == 'Pods'
    end
  end

  #---------------------------------------#

  describe "User project" do
    before do
      user_project_path = fixture('SampleProject/SampleProject.xcodeproj')
      project = Pod::Project.new(config.sandbox)
      podfile = Pod::Podfile.new do
        platform :ios
        xcodeproj user_project_path
        pod 'JSONKit'
      end
      @target_definition = podfile.target_definitions.values.first
      @lib = project.add_pod_library(@target_definition)
    end

    it "returns the user project path" do
      path = fixture('SampleProject/SampleProject.xcodeproj')
      @lib.user_project_path.should == path
    end

    it "raises if no project could be selected" do
      @target_definition.stubs(:user_project_path).returns(nil)
      Pathname.any_instance.stubs(:exist?).returns(true)
      lambda { @lib.user_project_path }.should.raise Pod::Informative
    end

    it "raises if the project path doesn't exist" do
      Pathname.any_instance.stubs(:exist?).returns(false)
      lambda { @lib.user_project_path }.should.raise Pod::Informative
    end

    it "returns the user project" do
      @lib.user_project.class.should == Xcodeproj::Project
    end

    it "returns the user targets associated with the target definition" do
      @lib.user_targets.all? { |t| t.isa == 'PBXNativeTarget' }.should.be.true
      @lib.user_targets.map(&:name).should == [ 'SampleProject' ]
    end

    it "uses the targets specified to link with by the target definition" do
      @target_definition.stubs(:link_with).returns(['TestRunner'])
      @target_definition.stubs(:name).returns('NON-EXISTING')
      @lib.user_targets.first.name.should == 'TestRunner'
    end

    it "it raises if it can't find any target specified to link with by the target definition" do
      @target_definition.stubs(:link_with).returns(['NON-EXISTING'])
      lambda { @lib.user_targets }.should.raise Pod::Informative
    end

    it "uses the target with the same name if the target definition name is different from `:default'" do
      @target_definition.stubs(:name).returns('TestRunner')
      @lib.user_targets.first.name.should == 'TestRunner'
    end

    it "it raises if it can't find a target with the same name of the target definition" do
      @target_definition.stubs(:name).returns('NON-EXISTING')
      lambda { @lib.user_targets }.should.raise Pod::Informative
    end

    it "uses the first target in the user's project if no explicit target is specified for the default target definition" do
      project = Xcodeproj::Project.new(@lib.user_project_path)
      @lib.user_targets.should == [ project.targets.first ]
    end
  end

  #---------------------------------------#

  describe "TargetInstaller & UserProjectIntegrator" do
    before do
      user_project_path = fixture('SampleProject/SampleProject.xcodeproj')
      project = Pod::Project.new(config.sandbox)
      podfile = Pod::Podfile.new do
        platform :ios
        xcodeproj user_project_path
        pod 'JSONKit'
      end
      @target_definition = podfile.target_definitions.values.first
      @lib = project.add_pod_library(@target_definition)
    end

    #---------------------------------------#

    it "returns the name of its product" do
      @lib.name.should == 'libPods.a'
    end

    it "returns it Pods project" do
      @lib.project.path.should == config.sandbox.project_path
    end

    #---------------------------------------#

    it "stores the xcconfig" do
      @lib.xcconfig = Xcodeproj::Config.new({'PODS_ROOT' => '${SRCROOT}'})
      @lib.xcconfig.to_hash['PODS_ROOT'].should == '${SRCROOT}'
    end

    it "returns the xcconfig name" do
      @lib.xcconfig_name.should == 'Pods.xcconfig'
    end

    it "returns the absolute path of the xcconfig file" do
      @lib.xcconfig_path.to_s.should.include?('Pods/Pods.xcconfig')
    end

    it "returns the path of the xcconfig file relative to the user project" do
      @lib.xcconfig_relative_path.should == '../../../tmp/Pods/Pods.xcconfig'
    end

    it "returns the resources script name" do
      @lib.copy_resources_script_name.should == 'Pods-resources.sh'
    end

    it "returns the absolute path of the resources script" do
      @lib.copy_resources_script_path.to_s.should.include?('Pods/Pods-resources.sh')
    end

    it "returns the path of the resources script relative to the user project" do
      @lib.copy_resources_script_relative_path.should == '${SRCROOT}/../../../tmp/Pods/Pods-resources.sh'
    end

    it "returns the prefix header file name" do
      @lib.prefix_header_name.should == 'Pods-prefix.pch'
    end

    it "returns the absolute path of the prefix header file" do
      @lib.prefix_header_path.to_s.should.include?('Pods/Pods-prefix.pch')
    end

    it "returns the bridge support file name" do
      @lib.bridge_support_name.should == 'Pods.bridgesupport'
    end

    it "returns the absolute path of the bridge support file" do
      @lib.bridge_support_path.to_s.should.include?('Pods/Pods.bridgesupport')
    end

  end
end
