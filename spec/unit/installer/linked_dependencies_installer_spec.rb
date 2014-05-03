require File.expand_path('../../../spec_helper', __FILE__)

def execute_command(command)
  if ENV['VERBOSE']
    sh(command)
  else
    output = `#{command} 2>&1`
    raise output unless $?.success?
  end
end

module Pod
  describe Installer::LinkedDependenciesInstaller do

  before do
    @target_definition = Podfile::TargetDefinition.new('Pods', nil)
    @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
    @project = Project.new(config.sandbox.project_path)
    @project.add_pod_group('BananaLib', fixture('banana-lib'))
    @pod_target = PodTarget.new([@file_accessor.spec], @target_definition, config.sandbox)
    @pod_target.file_accessors = [@file_accessor]
    @pod_target.target = @project.new_target(:static_library, 'Pod-BananaLib', :ios)
    @installer = Installer::LinkedDependenciesInstaller.new(@project, @file_accessor.root, @pod_target)
  end

  #-------------------------------------------------------------------------#

  describe "Installation" do

    describe "#install!" do

      it "adds libraries to target when installing" do
        @installer.expects(:add_libraries_to_target)
        @installer.stubs(:add_linked_projects)
        @installer.install!
      end

      it "adds linked projects when installing" do
        @installer.expects(:add_linked_projects)
        @installer.stubs(:add_libraries_to_target)
        @installer.install!
      end

    end

    it "adds subproject libraries to targets" do
      spec = @file_accessor.spec
      spec.xcodeproj = {
        :project => '../SampleProject/Sample Lib/Sample Lib.xcodeproj',
        :library_targets => ['Sample Lib']
      }

      @pod_target.stubs(:spec_consumers).returns([
        spec.consumer(:ios)
      ])

      # Add the linked project to the pods project, otherwise add_libraries_to_target will fail
      path = SpecHelper::Fixture.fixture('SampleProject/Sample Lib/Sample Lib.xcodeproj')
      @project.add_file_reference(path, @project.main_group)

      # Check that the schemes are hidden
      Xcodeproj::Project.any_instance.expects(:recreate_user_schemes).with(false)

      @installer.send(:add_libraries_to_target)

      @pod_target.target.frameworks_build_phase.files_references.map(&:path).should.include('libSample Lib.a')
    end

    it "adds linked projects" do
      path = SpecHelper::Fixture.fixture('SampleProject/Sample Lib/Sample Lib.xcodeproj')
      @installer.stubs(:linked_project_specs).returns({
        path => [@file_accessor.spec]
      })
      @installer.send(:add_linked_projects)

      @project.reference_for_path(path).isa.should.be == 'PBXFileReference'
    end

    it "does not add linked projects twice" do
      path = SpecHelper::Fixture.fixture('SampleProject/Sample Lib/Sample Lib.xcodeproj')
      @installer.stubs(:linked_project_specs).returns({
        path => [@file_accessor.spec]
      })
      @installer.send(:add_linked_projects)
      @installer.send(:add_linked_projects)

      @project.objects.find_all do |child|
        child.isa == 'PBXFileReference' && child.real_path == path
      end.length.should.be == 1
    end

  end

  #-------------------------------------------------------------------------#

  describe "Private Helpers" do

    it "opens a linked xcode project by path" do
      @installer.send(:open_linked_xcode_project, "../SampleProject/SampleProject.xcodeproj").path.basename.to_s.should == 'SampleProject.xcodeproj'
    end

    it "does not open a linked xcode project if the path is incorrect" do
      should.raise Informative do
        @installer.send(:open_linked_xcode_project, "hello")
      end.message.should.match /Could not open project/
    end

    it "links targets by name with the pod target" do
      lib_project = Xcodeproj::Project.open(SpecHelper::Fixture.fixture('SampleProject/Sample Lib/Sample Lib.xcodeproj'))
      @project.add_file_reference(lib_project.path, @project.main_group)

      @installer.send(:link_targets_with_target, lib_project, ['Sample Lib'])

      @pod_target.target.frameworks_build_phase.files_references.map(&:path).should.include('libSample Lib.a')
    end

    it "links a target with another target" do
      sample_project = Xcodeproj::Project.open(SpecHelper::Fixture.fixture('SampleProject/SampleProject.xcodeproj'))
      lib_project = Xcodeproj::Project.open(SpecHelper::Fixture.fixture('SampleProject/Sample Lib/Sample Lib.xcodeproj'))

      sample_project.main_group.new_file(lib_project.path)

      app_target = @installer.send(:find_named_native_target_in_project, sample_project, 'TestRunner')
      lib_target = @installer.send(:find_named_native_target_in_project, lib_project, 'Sample Lib')

      # Change the name of the lib_target product in order to test that we link
      # against that and not just the target name.
      lib_target.product_reference.path = 'libLib.a'

      @installer.send(:link_target_with_target, app_target, lib_target)

      app_target.dependencies.map(&:target).should.include(lib_target)
      app_target.frameworks_build_phase.files_references.map(&:path).should.include('libLib.a')
    end

    it "finds that no specs specifies linked projects" do
      @pod_target.stubs(:spec_consumers).returns([
        @file_accessor.spec.consumer(:ios)
      ])
      @installer.send(:linked_project_specs).should.be == {}
    end

    it "finds specs that specify linked projects" do
      spec = @file_accessor.spec
      spec.xcodeproj = { :project => 'hello' }

      @pod_target.stubs(:spec_consumers).returns([
        spec.consumer(:ios)
      ])
      @installer.send(:linked_project_specs).should.be == {
        (@file_accessor.root + 'hello') => [spec]
      }
    end

    it "finds a native target in a project" do
      project = Xcodeproj::Project.open(SpecHelper::Fixture.fixture('SampleProject/SampleProject.xcodeproj'))

      @installer.send(:find_named_native_target_in_project, project, 'SampleProject').isa.should == 'PBXNativeTarget'
    end

    it "does not find a nonexistent native target in a project" do
      project = Xcodeproj::Project.open(SpecHelper::Fixture.fixture('SampleProject/SampleProject.xcodeproj'))

      should.raise Informative do
        @installer.send(:find_named_native_target_in_project, project, 'SampleProject_nonexistent')
      end.message.should.match /Could not find native target/
    end

    it "extracts a single xcodeproj from a consumer object" do
      spec = @file_accessor.spec
      spec.xcodeproj = { :project => 'hello' }
      @installer.send(:xcodeprojs_from_consumer, spec.consumer(:ios)).should.be == [{ "project" => "hello" }]
    end

    it "extracts two xcodeprojs from a consumer object" do
      spec = @file_accessor.spec
      spec.xcodeprojs = [{ :project => 'hello' }, { 'project' => 'hello2' }]

      xcodeprojs = @installer.send(:xcodeprojs_from_consumer, spec.consumer(:ios))
      xcodeprojs.should.be == [{ "project" => "hello" }, { "project" => "hello2" }]
    end

    it "finds the spec file path correctly" do
      @installer.send(:spec_file).should.be == @file_accessor.spec.defined_in_file
    end

  end

  #-------------------------------------------------------------------------#

  describe "Functional Tests" do

    it "actually compiles and links properly" do
      load(fixture('XcodeprojTest/clean.rb'))

      begin
        Dir.chdir(fixture('XcodeprojTest')) do
          pod_command = 'bundle exec ../../../bin/sandbox-pod'
          execute_command "#{pod_command} install --verbose --no-repo-update 2>&1"

          # Create the XcodeprojTest scheme, in order to be able to build with xcodebuild
          testproj = Xcodeproj::Project.open(fixture('XcodeprojTest/XcodeprojTest.xcodeproj'))
          testproj.recreate_user_schemes

          execute_command "xcodebuild -workspace XcodeprojTest.xcworkspace -scheme XcodeprojTest -configuration Release install DSTROOT=$(pwd)"

          `./usr/local/bin/XcodeprojTest 2>&1`.should.match /Success/
          $?.success?.should.be.true
        end
      ensure
        load(fixture('XcodeprojTest/clean.rb'))
      end
    end

  end

  #-------------------------------------------------------------------------#

  end
end


