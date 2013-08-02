require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  describe Installer::Analyzer::UserProjectAnalyzer do

    describe "in general" do
      before do
        @project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @target_definition = Podfile::TargetDefinition.new('SampleProject', nil)
        @sut = Installer::Analyzer::UserProjectAnalyzer.new([@target_definition], @project_path.dirname)
      end

      it "performs the analysis" do
        results = @sut.analyze
        results.keys.should == [@target_definition]
        result = results[@target_definition]
        result.project_path.should == @project_path
        result.project.class.should == Xcodeproj::Project
        result.targets.map(&:name).should == ['SampleProject']
        result.build_configurations.should == {"Test"=>:release, "App Store"=>:release}
        result.platform.should == Platform.new(:ios, '5.0')
      end
    end

    #-------------------------------------------------------------------------#

    describe "#user_project_path" do
      before do
        @project_path = SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @target_definition = Podfile::TargetDefinition.new('SampleProject', nil)
        @sut = Installer::Analyzer::UserProjectAnalyzer.new([@target_definition], @project_path.dirname)
      end

      it "uses the path specified in the target definition while computing the path of the user project" do
        @target_definition.user_project_path = @project_path
        path = @sut.send(:user_project_path, @target_definition)
        path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
      end

      it "raises if the user project specified in the target definition does not exists" do
        @target_definition.user_project_path = 'Test'
        should.raise Informative do
          @sut.send(:user_project_path, @target_definition)
        end.message.should.match /Unable to find/
      end

      it "if not specified in the target definition if looks if there is only one project" do
        path = @sut.send(:user_project_path, @target_definition)
        path.to_s.should.include 'SampleProject/SampleProject.xcodeproj'
      end

      it "raises if no project is available" do
        @sut = Installer::Analyzer::UserProjectAnalyzer.new([@target_definition], '/tmp')
        should.raise Informative do
          @sut.send(:user_project_path, @target_definition)
        end.message.should.match /Could not.*select.*project/
      end
    end

    #-------------------------------------------------------------------------#

    describe "#project_targets" do
      before do
        @sut = Installer::Analyzer::UserProjectAnalyzer.new([], '/tmp')
      end

      it "returns the targets specified in the target definition" do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.link_with = ['UserTarget']
        user_project = Xcodeproj::Project.new
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)
        targets = @sut.send(:project_targets, target_definition, user_project)
        targets.map(&:name).should == ['UserTarget']
      end

      it "raises if it is unable to find the targets specified by the target definition" do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.link_with = ['UserTarget']
        user_project = Xcodeproj::Project.new
        should.raise Informative do
          @sut.send(:project_targets, target_definition, user_project)
        end.message.should.match /Unable to find the targets/
      end

      it "returns the target with the same name of the target definition" do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)
        targets = @sut.send(:project_targets, target_definition, user_project)
        targets.map(&:name).should == ['UserTarget']
      end

      it "raises if the name of the target definition does not match any target" do
        target_definition = Podfile::TargetDefinition.new('UserTarget', nil)
        user_project = Xcodeproj::Project.new
        should.raise Informative do
          @sut.send(:project_targets, target_definition, user_project)
        end.message.should.match /Unable to find a target named/
      end

      it "returns the first target of the project if needed" do
        target_definition = Podfile::TargetDefinition.new('Pods', nil)
        target_definition.link_with_first_target = true
        user_project = Xcodeproj::Project.new
        user_project.new_target(:application, 'FirstTarget', :ios)
        user_project.new_target(:application, 'UserTarget', :ios)
        targets = @sut.send(:project_targets, target_definition, user_project)
        targets.map(&:name).should == ['FirstTarget']
      end

      it "raises if there are no user targets" do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        user_project = Xcodeproj::Project.new
        should.raise Informative do
          @sut.send(:project_targets, target_definition, user_project)
        end.message.should.match /Unable to find a target/
      end
    end

    #-------------------------------------------------------------------------#

    describe "#build_configurations" do
      before do
        @sut = Installer::Analyzer::UserProjectAnalyzer.new([], '/tmp')
      end

      it "returns the user build configurations of the user targets" do
        user_project = Xcodeproj::Project.new
        target = user_project.new_target(:application, 'Target', :ios)
        configuration = user_project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
        configuration.name = 'AppStore'
        target.build_configuration_list.build_configurations << configuration
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        configurations = @sut.send(:build_configurations, target_definition, [target])
        configurations.should == { 'AppStore' => :release }
      end

      it "returns the user build configurations specified in the target definition" do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.build_configurations = { 'AppStore' => :release }
        configurations = @sut.send(:build_configurations, target_definition, [])
        configurations.should == { 'AppStore' => :release }
      end
    end

    #-------------------------------------------------------------------------#

    describe "#platform" do
      before do
        @sut = Installer::Analyzer::UserProjectAnalyzer.new([], '/tmp')
      end

      it "returns the platform specified in the target definition" do
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        target_definition.set_platform(:ios, '4.0')
        configurations = @sut.send(:platform, target_definition, [])
        configurations.should == Platform.new(:ios, '4.0')
      end

      it "infers the platform from the user targets" do
        user_project = Xcodeproj::Project.new
        target = user_project.new_target(:application, 'Target', :ios, '4.0')
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        configurations = @sut.send(:platform, target_definition, [target])
        configurations.should == Platform.new(:ios, '4.0')
      end

      it "uses the lowest deployment target of the user targets if inferring the platform" do
        user_project = Xcodeproj::Project.new
        target1 = user_project.new_target(:application, 'Target', :ios, '4.0')
        target2 = user_project.new_target(:application, 'Target', :ios, '6.0')
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        configurations = @sut.send(:platform, target_definition, [target1, target2])
        configurations.should == Platform.new(:ios, '4.0')
      end

      it "raises if the user targets have a different platform" do
        user_project = Xcodeproj::Project.new
        target1 = user_project.new_target(:application, 'Target', :ios, '4.0')
        target2 = user_project.new_target(:application, 'Target', :osx, '10.6')
        target_definition = Podfile::TargetDefinition.new(:default, nil)
        should.raise Informative do
          @sut.send(:platform, target_definition, [target1, target2])
        end.message.should.match /Targets with different platforms/
      end
    end

    #-------------------------------------------------------------------------#

    describe "Helpers" do
      before do
        @sut = Installer::Analyzer::UserProjectAnalyzer.new([], '/tmp')
      end

      describe "#normalize_project_path" do
        it "returns the path if already normalized" do
          path = '/my_project/project.xcodeproj'
          result = @sut.send(:normalize_project_path, path, '/project')
          result.to_s.should == '/my_project/project.xcodeproj'
        end

        it "appends the extension if needed" do
          path = '/my_project/project'
          result = @sut.send(:normalize_project_path, path, '/project')
          result.to_s.should == '/my_project/project.xcodeproj'
        end

        it "appends the path to the installation root if relative" do
          path = 'project.xcodeproj'
          result = @sut.send(:normalize_project_path, path, '/project')
          result.to_s.should == '/project/project.xcodeproj'
        end
      end

      describe "#native_targets" do
        it "returns the native targets of the given project" do
          project = Xcodeproj::Project.new
          project.new_target(:application, 'MyApp', :ios)
          native_targets = @sut.send(:native_targets, project).map(&:name)
          native_targets.should == ['MyApp']
        end

        it "rejects the aggregate targets" do
          project = Xcodeproj::Project.new
          project.new_target(:application, 'MyApp', :ios)
          native_targets = @sut.send(:native_targets, project).map(&:name)
          native_targets.should == ['MyApp']
          target = project.new('PBXAggregateTarget')
          target.name = 'Aggregate'
          project.targets << target

          native_targets = @sut.send(:native_targets, project).map(&:name)
          native_targets.should == ['MyApp']
        end
      end
    end

    #-------------------------------------------------------------------------#

  end
end
