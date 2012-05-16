require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Podfile" do
  it "loads from a file" do
    podfile = Pod::Podfile.from_file(fixture('Podfile'))
    podfile.defined_in_file.should == fixture('Podfile')
  end

  it "assigns the platform attribute to the current target" do
    podfile = Pod::Podfile.new { platform :ios }
    podfile.target_definitions[:default].platform.should == :ios
  end

  it "adds dependencies" do
    podfile = Pod::Podfile.new { dependency 'ASIHTTPRequest'; dependency 'SSZipArchive', '>= 0.1' }
    podfile.dependencies.size.should == 2
    podfile.dependency_by_top_level_spec_name('ASIHTTPRequest').should == Pod::Dependency.new('ASIHTTPRequest')
    podfile.dependency_by_top_level_spec_name('SSZipArchive').should == Pod::Dependency.new('SSZipArchive', '>= 0.1')
  end

  it "adds a dependency on a Pod repo outside of a spec repo (the repo is expected to contain a podspec)" do
    podfile = Pod::Podfile.new do
      dependency 'SomeExternalPod', :git => 'GIT-URL', :commit => '1234'
    end
    dep = podfile.dependency_by_top_level_spec_name('SomeExternalPod')
    dep.external_source.params.should == { :git => 'GIT-URL', :commit => '1234' }
  end

  it "adds a subspec dependency on a Pod repo outside of a spec repo (the repo is expected to contain a podspec)" do
    podfile = Pod::Podfile.new do
      dependency 'MainSpec/FirstSubSpec', :git => 'GIT-URL', :commit => '1234'
    end
    dep = podfile.dependency_by_top_level_spec_name('MainSpec')
    dep.external_source.name.should == 'MainSpec'
  end

  it "adds a dependency on a library outside of a spec repo (the repo does not need to contain a podspec)" do
    podfile = Pod::Podfile.new do
      dependency 'SomeExternalPod', :podspec => 'http://gist/SomeExternalPod.podspec'
    end
    dep = podfile.dependency_by_top_level_spec_name('SomeExternalPod')
    dep.external_source.params.should == { :podspec => 'http://gist/SomeExternalPod.podspec' }
  end

  it "adds a dependency on a library by specifying the podspec inline" do
    podfile = Pod::Podfile.new do
      dependency do |s|
        s.name = 'SomeExternalPod'
      end
    end
    dep = podfile.dependency_by_top_level_spec_name('SomeExternalPod')
    dep.specification.name.should == 'SomeExternalPod'
  end

  it "specifies that BridgeSupport metadata should be generated" do
    Pod::Podfile.new {}.should.not.generate_bridge_support
    Pod::Podfile.new { generate_bridge_support! }.should.generate_bridge_support
  end

  it 'specifies that ARC compatibility flag should be generated' do
    Pod::Podfile.new { set_arc_compatibility_flag! }.should.set_arc_compatibility_flag
  end

  it "stores a block that will be called with the Installer instance once installation is finished (but the project is not written to disk yet)" do
    yielded = nil
    Pod::Podfile.new do
      post_install do |installer|
        yielded = installer
      end
    end.post_install!(:an_installer)
    yielded.should == :an_installer
  end

  it "assumes the xcode project is the only existing project in the root" do
    podfile = Pod::Podfile.new do
      target(:another_target) {}
    end

    path = config.project_root + 'MyProject.xcodeproj'
    config.project_root.expects(:glob).with('*.xcodeproj').returns([path])

    podfile.target_definitions[:default].user_project.path.should == path
    podfile.target_definitions[:another_target].user_project.path.should == path
  end

  it "assumes the basename of the workspace is the same as the default target's project basename" do
    path = config.project_root + 'MyProject.xcodeproj'
    config.project_root.expects(:glob).with('*.xcodeproj').returns([path])
    Pod::Podfile.new {}.workspace.should == config.project_root + 'MyProject.xcworkspace'

    Pod::Podfile.new do
      xcodeproj 'AnotherProject.xcodeproj'
    end.workspace.should == config.project_root + 'AnotherProject.xcworkspace'
  end

  it "does not base the workspace name on the default target's project if there are multiple projects specified" do
    Pod::Podfile.new do
      xcodeproj 'MyProject'
      target :another_target do
        xcodeproj 'AnotherProject'
      end
    end.workspace.should == nil
  end

  it "specifies the Xcode workspace to use" do
    Pod::Podfile.new do
      xcodeproj 'AnotherProject'
      workspace 'MyWorkspace'
    end.workspace.should == config.project_root + 'MyWorkspace.xcworkspace'
    Pod::Podfile.new do
      xcodeproj 'AnotherProject'
      workspace 'MyWorkspace.xcworkspace'
    end.workspace.should == config.project_root + 'MyWorkspace.xcworkspace'
  end

  describe "concerning targets (dependency groups)" do
    it "returns wether or not a target has any dependencies" do
      Pod::Podfile.new do
      end.target_definitions[:default].should.be.empty
      Pod::Podfile.new do
        dependency 'JSONKit'
      end.target_definitions[:default].should.not.be.empty
    end

    before do
      @podfile = Pod::Podfile.new do
        platform :ios
        xcodeproj 'iOS Project', 'iOS App Store' => :release, 'Test' => :debug

        target :debug do
          dependency 'SSZipArchive'
        end

        target :test, :exclusive => true do
          link_with 'TestRunner'
          dependency 'JSONKit'
          target :subtarget do
            dependency 'Reachability'
          end
        end

        target :osx_target do
          platform :osx
          xcodeproj 'OSX Project.xcodeproj', 'Mac App Store' => :release, 'Test' => :debug
          link_with 'OSXTarget'
          dependency 'ASIHTTPRequest'
          target :nested_osx_target do
          end
        end

        dependency 'ASIHTTPRequest'
      end
    end

    it "returns all dependencies of all targets combined, which is used during resolving to ensure compatible dependencies" do
      @podfile.dependencies.map(&:name).sort.should == %w{ ASIHTTPRequest JSONKit Reachability SSZipArchive }
    end

    it "adds dependencies outside of any explicit target block to the default target" do
      target = @podfile.target_definitions[:default]
      target.label.should == 'Pods'
      target.dependencies.should == [Pod::Dependency.new('ASIHTTPRequest')]
    end

    it "adds dependencies of the outer target to non-exclusive targets" do
      target = @podfile.target_definitions[:debug]
      target.label.should == 'Pods-debug'
      target.dependencies.sort_by(&:name).should == [
        Pod::Dependency.new('ASIHTTPRequest'),
        Pod::Dependency.new('SSZipArchive')
      ]
    end

    it "does not add dependencies of the outer target to exclusive targets" do
      target = @podfile.target_definitions[:test]
      target.label.should == 'Pods-test'
      target.dependencies.should == [Pod::Dependency.new('JSONKit')]
    end

    it "adds dependencies of the outer target to nested targets" do
      target = @podfile.target_definitions[:subtarget]
      target.label.should == 'Pods-test-subtarget'
      target.dependencies.should == [Pod::Dependency.new('Reachability'), Pod::Dependency.new('JSONKit')]
    end

    it "returns the Xcode project that contains the target to link with" do
      [:default, :debug, :test, :subtarget].each do |target_name|
        target = @podfile.target_definitions[target_name]
        target.user_project.path.should == config.project_root + 'iOS Project.xcodeproj'
      end
      [:osx_target, :nested_osx_target].each do |target_name|
        target = @podfile.target_definitions[target_name]
        target.user_project.path.should == config.project_root + 'OSX Project.xcodeproj'
      end
    end

    it "returns a Xcode project found in the working dir when no explicit project is specified" do
      xcodeproj1 = config.project_root + '1.xcodeproj'
      config.project_root.expects(:glob).with('*.xcodeproj').returns([xcodeproj1])
      Pod::Podfile::UserProject.new.path.should == xcodeproj1
    end

    it "returns `nil' if more than one Xcode project was found in the working when no explicit project is specified" do
      xcodeproj1, xcodeproj2 = config.project_root + '1.xcodeproj', config.project_root + '2.xcodeproj'
      config.project_root.expects(:glob).with('*.xcodeproj').returns([xcodeproj1, xcodeproj2])
      Pod::Podfile::UserProject.new.path.should == nil
    end

    it "leaves the name of the target, to link with, to be automatically resolved" do
      target = @podfile.target_definitions[:default]
      target.link_with.should == nil
    end

    it "returns the names of the explicit targets to link with" do
      target = @podfile.target_definitions[:test]
      target.link_with.should == ['TestRunner']
    end

    it "returns the name of the Pods static library" do
      @podfile.target_definitions[:default].lib_name.should == 'libPods.a'
      @podfile.target_definitions[:test].lib_name.should == 'libPods-test.a'
    end

    it "returns the name of the xcconfig file for the target" do
      @podfile.target_definitions[:default].xcconfig_name.should == 'Pods.xcconfig'
      @podfile.target_definitions[:default].xcconfig_relative_path.should == 'Pods/Pods.xcconfig'
      @podfile.target_definitions[:test].xcconfig_name.should == 'Pods-test.xcconfig'
      @podfile.target_definitions[:test].xcconfig_relative_path.should == 'Pods/Pods-test.xcconfig'
    end

    it "returns the name of the 'copy resources script' file for the target" do
      @podfile.target_definitions[:default].copy_resources_script_name.should == 'Pods-resources.sh'
      @podfile.target_definitions[:default].copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Pods-resources.sh'
      @podfile.target_definitions[:test].copy_resources_script_name.should == 'Pods-test-resources.sh'
      @podfile.target_definitions[:test].copy_resources_script_relative_path.should == '${SRCROOT}/Pods/Pods-test-resources.sh'
    end

    it "returns the name of the 'prefix header' file for the target" do
      @podfile.target_definitions[:default].prefix_header_name.should == 'Pods-prefix.pch'
      @podfile.target_definitions[:test].prefix_header_name.should == 'Pods-test-prefix.pch'
    end

    it "returns the name of the BridgeSupport file for the target" do
      @podfile.target_definitions[:default].bridge_support_name.should == 'Pods.bridgesupport'
      @podfile.target_definitions[:test].bridge_support_name.should == 'Pods-test.bridgesupport'
    end

    it "returns the platform of the target" do
      @podfile.target_definitions[:default].platform.should == :ios
      @podfile.target_definitions[:test].platform.should == :ios
      @podfile.target_definitions[:osx_target].platform.should == :osx
    end

    it "autmatically marks a target as exclusive if the parent platform doesn't match" do
      @podfile.target_definitions[:osx_target].should.be.exclusive
      @podfile.target_definitions[:nested_osx_target].should.not.be.exclusive
    end

    it "returns the specified configurations and wether it should be based on a debug or a release build" do
      Pod::Podfile::UserProject.any_instance.stubs(:project)
      all = { 'Release' => :release, 'Debug' => :debug, 'Test' => :debug }
      @podfile.target_definitions[:default].user_project.build_configurations.should == all.merge('iOS App Store' => :release)
      @podfile.target_definitions[:test].user_project.build_configurations.should == all.merge('iOS App Store' => :release)
      @podfile.target_definitions[:osx_target].user_project.build_configurations.should == all.merge('Mac App Store' => :release)
      @podfile.target_definitions[:nested_osx_target].user_project.build_configurations.should == all.merge('Mac App Store' => :release)
      @podfile.user_build_configurations.should == all.merge('iOS App Store' => :release, 'Mac App Store' => :release)
    end

    it "defaults, for unspecified configurations, to a release build" do
      project = Pod::Podfile::UserProject.new(fixture('SampleProject/SampleProject.xcodeproj'), 'Test' => :debug)
      project.build_configurations.should == { 'Release' => :release, 'Debug' => :debug, 'Test' => :debug, 'App Store' => :release }
    end

    describe "with an Xcode project that's not in the project_root" do
      before do
        @target_definition = @podfile.target_definitions[:default]
        @target_definition.user_project.stubs(:path).returns(config.project_root + 'subdir/iOS Project.xcodeproj')
      end

      it "returns the $(PODS_ROOT) relative to the project's $(SRCROOT)" do
        @target_definition.relative_pods_root.should == '${SRCROOT}/../Pods'
      end

      it "simply returns the $(PODS_ROOT) path if no xcodeproj file is available and doesn't needs to integrate" do
        config.integrate_targets.should.equal true
        config.integrate_targets = false
        @target_definition.relative_pods_root.should == '${SRCROOT}/../Pods'
        @target_definition.user_project.stubs(:path).returns(nil)
        @target_definition.relative_pods_root.should == '${SRCROOT}/Pods'
        config.integrate_targets = true
      end

      it "returns the xcconfig file path relative to the project's $(SRCROOT)" do
        @target_definition.xcconfig_relative_path.should == '../Pods/Pods.xcconfig'
      end

      it "returns the 'copy resources script' path relative to the project's $(SRCROOT)" do
        @target_definition.copy_resources_script_relative_path.should == '${SRCROOT}/../Pods/Pods-resources.sh'
      end
    end
  end

  describe "concerning validations" do

    it "raises if it should integrate and can't find an xcodeproj" do
      config.integrate_targets = true
      target_definition = Pod::Podfile.new {}.target_definitions[:default]
      target_definition.user_project.stubs(:path).returns(nil)
      exception = lambda {
        target_definition.relative_pods_root
        }.should.raise Pod::Informative
      exception.message.should.include "Xcode project"
    end

    xit "raises if no platform is specified" do
      exception = lambda {
        Pod::Podfile.new {}.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "platform"
    end

    xit "raises if an invalid platform is specified" do
      exception = lambda {
        Pod::Podfile.new { platform :windows }.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "platform"
    end

    xit "raises if no dependencies were specified" do
      exception = lambda {
        Pod::Podfile.new {}.validate!
      }.should.raise Pod::Informative
      exception.message.should.include "dependencies"
    end
  end
end
