require File.expand_path('../../spec_helper', __FILE__)

# @return [Analyzer] the sample analyzer.
#
def create_analyzer
  podfile = Pod::Podfile.new do
    platform :ios, '6.0'
    xcodeproj 'SampleProject/SampleProject'
    pod 'JSONKit',                     '1.5pre'
    pod 'AFNetworking',                '1.0.1'
    pod 'SVPullToRefresh',             '0.4'
    pod 'libextobjc/EXTKeyPathCoding', '0.2.3'
  end

  hash = {}
  hash['PODS'] = ["JSONKit (1.4)", "NUI (0.2.0)", "SVPullToRefresh (0.4)"]
  hash['DEPENDENCIES'] = ["JSONKit", "NUI", "SVPullToRefresh"]
  hash['SPEC CHECKSUMS'] = {}
  hash['COCOAPODS'] = Pod::VERSION
  lockfile = Pod::Lockfile.new(hash)

  SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
  analyzer = Pod::Analyzer.new(config.sandbox, podfile, lockfile)
end

#-----------------------------------------------------------------------------#

module Pod
  describe Analyzer do

    before do
      @analyzer = create_analyzer
    end

    describe "Analysis" do

      it "returns whether an installation should be performed" do
        @analyzer.needs_install?.should.be.true
      end

      it "returns whether the Podfile has changes" do
        @analyzer.podfile_needs_install?.should.be.true
      end

      it "returns whether the sandbox is not in sync with the lockfile" do
        @analyzer.sandbox_needs_install?.should.be.true
      end

      #--------------------------------------#

      it "computes the state of the Podfile respect to the Lockfile" do
        @analyzer.analyze
        state = @analyzer.podfile_state
        state.added.should     == ["AFNetworking", "libextobjc"]
        state.changed.should   == ["JSONKit"]
        state.unchanged.should == ["SVPullToRefresh"]
        state.deleted.should   == ["NUI"]
      end

      #--------------------------------------#

      it "updates the repositories by default" do
        config.skip_repo_update = false
        SourcesManager.expects(:update).once
        @analyzer.analyze
      end

      it "does not updates the repositories if config indicates to skip them" do
        config.skip_repo_update = true
        SourcesManager.expects(:update).never
        @analyzer.analyze
      end

      #--------------------------------------#

      it "generates the libraries which represent the target definitions" do
        @analyzer.analyze
        libs = @analyzer.libraries
        libs.map(&:name).should == ['libPods.a']
        lib = libs.first
        lib.support_files_root.should == config.sandbox.root

        lib.user_project_path.to_s.should.include 'SampleProject/SampleProject'
        lib.user_project.class.should == Xcodeproj::Project
        lib.user_targets.map(&:name).should == ["SampleProject"]
        lib.user_build_configurations.should == {"Test"=>:release, "App Store"=>:release}
        lib.platform.to_s.should == 'iOS 6.0'
      end

      it "generates configures the library appropriately if the installation will not integrate" do
        config.integrate_targets = false
        @analyzer.analyze
        lib = @analyzer.libraries.first

        lib.user_project_path.should == config.project_root
        lib.user_project.should.be.nil
        lib.user_targets.map(&:name).should == []
        lib.user_build_configurations.should == {}
        lib.platform.to_s.should == 'iOS 6.0'
      end

      #--------------------------------------#

      it "locks the version of the dependencies which did not change in the Podfile" do
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:to_s).should == ["SVPullToRefresh"]
      end

      it "does not lock the dependencies in update mode" do
        @analyzer.update_mode = true
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:to_s).should == []
      end

      #--------------------------------------#

      it "resolves the dependencies" do
        @analyzer.analyze
        @analyzer.specifications.map(&:to_s).should == [
          "AFNetworking (1.0.1)",
          "JSONKit (1.5pre)",
          "SVPullToRefresh (0.4)",
          "libextobjc/EXTKeyPathCoding (0.2.3)"
        ]
      end

      it "adds the specifications to the correspondent libraries in after the resolution" do
        @analyzer.analyze
        @analyzer.libraries.first.specs.map(&:to_s).should == [
          "AFNetworking (1.0.1)",
          "JSONKit (1.5pre)",
          "SVPullToRefresh (0.4)",
          "libextobjc/EXTKeyPathCoding (0.2.3)"
        ]
      end

      it "instructs the resolver to not update external sources by default" do
        Resolver.any_instance.expects(:update_external_specs=).with(false)
        @analyzer.analyze
      end

      it "instructs the resolver to update external sources if in update mode" do
        Resolver.any_instance.expects(:update_external_specs=).with(true)
        @analyzer.update_mode = true
        @analyzer.analyze
      end

      it "allow pre downloads in the resolver by default" do
        Resolver.any_instance.expects(:allow_pre_downloads=).with(true)
        @analyzer.analyze
      end

      it "allow pre downloads in the resolver by default" do
        Resolver.any_instance.expects(:allow_pre_downloads=).with(false)
        @analyzer.allow_pre_downloads = false
        @analyzer.analyze
      end

      #--------------------------------------#

      it "computes the state of the Sandbox respect to the resolved dependencies" do
        @analyzer.stubs(:lockfile).returns(nil)
        @analyzer.analyze
        state = @analyzer.sandbox_state
        state.added.should     == ["AFNetworking", "JSONKit", "SVPullToRefresh", "libextobjc"]
      end

    end

    #-------------------------------------------------------------------------#

    describe "Private helpers" do

      describe "#compute_user_project_targets" do
        it "uses the path specified in the target definition while computing the path of the user project" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          target_definition.user_project_path = 'SampleProject/SampleProject'

          path = @analyzer.send(:compute_user_project_path, target_definition)
          path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
        end

        it "raises if the user project of the target definition does not exists while computing the path of the user project" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          target_definition.user_project_path = 'Test'

          e = lambda { @analyzer.send(:compute_user_project_path, target_definition) }.should.raise Informative
          e.message.should.match /Unable to find/
        end

        it "if not specified in the target definition if looks if there is only one project" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          config.project_root = config.project_root + 'SampleProject'

          path = @analyzer.send(:compute_user_project_path, target_definition)
          path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
        end

        it "if not specified in the target definition if looks if there is only one project" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)

          e = lambda { @analyzer.send(:compute_user_project_path, target_definition) }.should.raise Informative
          e.message.should.match /Could not.*select.*project/
        end
      end

      #--------------------------------------#

      describe "#compute_user_project_targets" do

        it "returns the targets specified in the target definition" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          target_definition.link_with = ['UserTarget']
          user_project = Xcodeproj::Project.new
          user_project.new_target(:application, 'FirstTarget', :ios)
          user_project.new_target(:application, 'UserTarget', :ios)

          targets = @analyzer.send(:compute_user_project_targets, target_definition, user_project)
          targets.map(&:name).should == ['UserTarget']
        end

        it "raises if it is unable to find the targets specified by the target definition" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          target_definition.link_with = ['UserTarget']
          user_project = Xcodeproj::Project.new

          e = lambda { @analyzer.send(:compute_user_project_targets, target_definition, user_project) }.should.raise Informative
          e.message.should.match /Unable to find the targets/
        end

        it "returns the target with the same name of the target definition" do
          target_definition = Podfile::TargetDefinition.new('UserTarget', nil, nil)
          user_project = Xcodeproj::Project.new
          user_project.new_target(:application, 'FirstTarget', :ios)
          user_project.new_target(:application, 'UserTarget', :ios)

          targets = @analyzer.send(:compute_user_project_targets, target_definition, user_project)
          targets.map(&:name).should == ['UserTarget']
        end

        it "raises if the name of the target definition does not match any file" do
          target_definition = Podfile::TargetDefinition.new('UserTarget', nil, nil)
          user_project = Xcodeproj::Project.new

          e = lambda { @analyzer.send(:compute_user_project_targets, target_definition, user_project) }.should.raise Informative
          e.message.should.match /Unable to find a target named/
        end

        it "returns the first target of the project if the target definition is named default" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          user_project = Xcodeproj::Project.new
          user_project.new_target(:application, 'FirstTarget', :ios)
          user_project.new_target(:application, 'UserTarget', :ios)

          targets = @analyzer.send(:compute_user_project_targets, target_definition, user_project)
          targets.map(&:name).should == ['FirstTarget']
        end

        it "raises if the default target definition cannot be linked because there are no user targets" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          user_project = Xcodeproj::Project.new

          e = lambda { @analyzer.send(:compute_user_project_targets, target_definition, user_project) }.should.raise Informative
          e.message.should.match /Unable to find a target/
        end

      end

      #--------------------------------------#

      describe "#compute_user_build_configurations" do

        it "returns the user build configurations of the user targets" do
          user_project = Xcodeproj::Project.new
          target = user_project.new_target(:application, 'Target', :ios)
          configuration = user_project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
          configuration.name = 'AppStore'
          target.build_configuration_list.build_configurations << configuration

          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          user_targets = [target]

          configurations = @analyzer.send(:compute_user_build_configurations, target_definition, user_targets)
          configurations.should == { 'AppStore' => :release }
        end


        it "returns the user build configurations specified in the target definition" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          target_definition.build_configurations = { 'AppStore' => :release }
          user_targets = []

          configurations = @analyzer.send(:compute_user_build_configurations, target_definition, user_targets)
          configurations.should == { 'AppStore' => :release }
        end

      end

      #--------------------------------------#

      describe "#compute_platform_for_target_definition" do

        it "returns the platform specified in the target definition" do
          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          target_definition.platform = Platform.new(:ios, '4.0')
          user_targets = []

          configurations = @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets)
          configurations.should == Platform.new(:ios, '4.0')
        end

        it "infers the platform from the user targets" do
          user_project = Xcodeproj::Project.new
          target = user_project.new_target(:application, 'Target', :ios)
          configuration = target.build_configuration_list.build_configurations.first
          configuration.build_settings = {
            'SDKROOT' => 'iphoneos',
            'IPHONEOS_DEPLOYMENT_TARGET' => '4.0'
          }

          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          user_targets = [target]

          configurations = @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets)
          configurations.should == Platform.new(:ios, '4.0')
        end

        it "uses the lowest deployment target of the user targets if inferring the platform" do
          user_project = Xcodeproj::Project.new
          target1 = user_project.new_target(:application, 'Target', :ios)
          configuration1 = target1.build_configuration_list.build_configurations.first
          configuration1.build_settings = {
            'SDKROOT' => 'iphoneos',
            'IPHONEOS_DEPLOYMENT_TARGET' => '4.0'
          }
          target2 = user_project.new_target(:application, 'Target', :ios)
          configuration2 = target2.build_configuration_list.build_configurations.first
          configuration2.build_settings = {
            'SDKROOT' => 'iphoneos',
            'IPHONEOS_DEPLOYMENT_TARGET' => '6.0'
          }

          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          user_targets = [target1, target2]

          configurations = @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets)
          configurations.should == Platform.new(:ios, '4.0')
        end

        it "raises if the user targets have a different platform" do
          user_project = Xcodeproj::Project.new
          target1 = user_project.new_target(:application, 'Target', :ios)
          configuration1 = target1.build_configuration_list.build_configurations.first
          configuration1.build_settings = {
            'SDKROOT' => 'iphoneos',
            'IPHONEOS_DEPLOYMENT_TARGET' => '4.0'
          }
          target2 = user_project.new_target(:application, 'Target', :ios)
          configuration2 = target2.build_configuration_list.build_configurations.first
          configuration2.build_settings = {
            'SDKROOT' => 'macosx',
            'IPHONEOS_DEPLOYMENT_TARGET' => '10.6'
          }

          target_definition = Podfile::TargetDefinition.new(:default, nil, nil)
          user_targets = [target1, target2]
          e = lambda { @analyzer.send(:compute_platform_for_target_definition, target_definition, user_targets) }.should.raise Informative
          e.message.should.match /Targets with different platforms/
        end

      end

      #--------------------------------------#

    end
  end
end
