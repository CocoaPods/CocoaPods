require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Installer
    describe PodsProjectGenerator do

      before do
        config.sandbox.stubs(:cocoapods_version).returns(Version.new(Pod::VERSION))
      end

      #-----------------------------------------------------------------------#

      describe "In general" do

        before do
          @sut = PodsProjectGenerator.new(config.sandbox, [])
        end

        it "performs an installation" do
          @sut.send(:install)
          @sut.project.should.not.be.nil
        end

        it "writes the pods project" do
          @sut.send(:install)
          @sut.project.expects(:prepare_for_serialization)
          @sut.project.expects(:save)
          @sut.send(:write_project)
        end

      end

      #-----------------------------------------------------------------------#

      describe "#prepare_project" do

        before do
          @sut = PodsProjectGenerator.new(config.sandbox, [])
          @sut.user_build_configurations = { 'App Store' => :release, 'Test' => :debug }
        end

        it "creates the Pods project" do
          @sut.send(:prepare_project)
          @sut.project.class.should == Pod::Project
        end

        xit "creates a group for each Pod" do
          pod_target = PodTarget.new([], nil, config.sandbox)
          pod_target.stubs(:pod_name).returns('BananaLib')
          @sut.stubs(:pod_targets).returns([pod_target])
          @sut.send(:prepare_project)
          @sut.project['Pods/BananaLib'].should.not.be.nil
        end

        xit "creates a group for each development Pod" do
          pod_target = PodTarget.new([], nil, config.sandbox)
          pod_target.stubs(:pod_name).returns('BananaLib')
          @sut.stubs(:pod_targets).returns([pod_target])
          config.sandbox.expects(:pod_dir).with('BananaLib').returns('/BananaLib')
          config.sandbox.expects(:local?).with('BananaLib').returns(true)
          @sut.send(:prepare_project)
          @sut.project['Development Pods/BananaLib'].should.not.be.nil
        end

        it "adds the Podfile to the project" do
          @sut.podfile_path = Pathname.new('/Podfile')
          @sut.send(:prepare_project)
          @sut.project['Podfile'].should.be.not.nil
        end

        it "adds the user build configurations to the project" do
          @sut.send(:prepare_project)
          @sut.project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
        end

        it "sets STRIP_INSTALLED_PRODUCT to NO for all configurations of the project" do
          @sut.send(:prepare_project)
          @sut.project.build_configurations.each do |build_configuration|
            build_configuration.build_settings["STRIP_INSTALLED_PRODUCT"].should == "NO"
          end
        end

        it "sets the deployment target for the project" do
          target_ios = Target.new('Pods-ios')
          target_ios.platform = Platform.ios
          target_ios.platform = Platform.new(:ios, '6.0')
          target_osx = Target.new('Pods-osx')
          target_osx.platform = Platform.new(:osx, '10.8')
          @sut.stubs(:aggregate_targets).returns([target_ios, target_osx])
          @sut.send(:prepare_project)
          build_settings = @sut.project.build_configurations.map(&:build_settings)
          build_settings.each do |build_setting|
            build_setting["MACOSX_DEPLOYMENT_TARGET"].should == '10.8'
            build_setting["IPHONEOS_DEPLOYMENT_TARGET"].should == '6.0'
          end
        end

      end

      #-----------------------------------------------------------------------#

      describe "#install_file_references" do

        before do
          @sut = PodsProjectGenerator.new(config.sandbox, [])
        end

        xit "installs the file references" do
          Installer::PodsProjectGenerator::FileReferencesInstaller.any_instance.expects(:install!)
          @sut.send(:install_file_references)
        end

      end

      #-----------------------------------------------------------------------#

      describe "#install_targets" do

        before do
          @target_definition = Podfile::TargetDefinition.new(:default, nil)
          pod_target = PodTarget.new([], @target_definition, config.sandbox)
          pod_target.stubs(:name).returns('BananaLib')
          aggregate_target = Target.new('Pods')
          aggregate_target.children = [pod_target]
          @sut = PodsProjectGenerator.new(config.sandbox, [aggregate_target])
        end

        xit "install the aggregate targets" do
          @target_definition.store_pod('BananaLib')
          Installer::PodsProjectGenerator::PodTargetInstaller.any_instance.stubs(:install!)
          Installer::PodsProjectGenerator::AggregateTargetInstaller.any_instance.expects(:install!)
          @sut.send(:install_targets)
        end

        xit "install the Pod targets" do
          @target_definition.store_pod('BananaLib')
          Installer::PodsProjectGenerator::AggregateTargetInstaller.any_instance.stubs(:install!)
          Installer::PodsProjectGenerator::PodTargetInstaller.any_instance.expects(:install!)
          @sut.send(:install_targets)
        end

        xit "skips empty targets" do
          Installer::PodsProjectGenerator::PodTargetInstaller.any_instance.expects(:install!).never
          Installer::PodsProjectGenerator::PodTargetInstaller.any_instance.expects(:install!).never
          @sut.send(:install_targets)
        end

      end

      #-----------------------------------------------------------------------#

      describe "#install_system_frameworks" do

        before do
          spec = Spec.new
          spec.frameworks = ['QuartzCore']
          pod_target = PodTarget.new([spec], nil, config.sandbox)
          pod_target.stubs(:pod_name).returns('BananaLib')
          pod_target.stubs(:platform).returns(:ios)
          @pod_native_target = stub()
          pod_target.target = @pod_native_target
          @sut = PodsProjectGenerator.new(config.sandbox, [])
          @sut.stubs(:pod_targets).returns([pod_target])
          @sut.send(:prepare_project)
        end

        xit 'adds the frameworks required by to the pod to the project for informative purposes' do
          Project.any_instance.expects(:add_system_framework).with('QuartzCore', @pod_native_target)
          @sut.send(:install_system_frameworks)
        end
      end

      #-----------------------------------------------------------------------#

      describe "#add_missing_aggregate_targets_libraries" do

        before do
          project = Pod::Project.new(config.sandbox.project_path)
          @aggregate_native_target = project.new_target(:static_library, 'Pods', :ios)
          @pod_native_target = project.new_target(:static_library, 'Pods-BananaLib', :ios)
          aggregate_target = Target.new('Pods')
          aggregate_target.target = @aggregate_native_target
          pod_target = Target.new('Pods-BananaLib', aggregate_target)
          pod_target.target = @pod_native_target
          @sut = PodsProjectGenerator.new(config.sandbox, [aggregate_target])
        end

        it "links the aggregate targets to the pod targets" do
          @sut.send(:add_missing_aggregate_targets_libraries)
          @aggregate_native_target.frameworks_build_phase.files.map(&:file_ref).should.include?(@pod_native_target.product_reference)
        end

      end

      #-----------------------------------------------------------------------#

      describe "#add_missing_target_dependencies" do

        before do
          project = Pod::Project.new(config.sandbox.project_path)
          aggregate_native_target = project.new_target(:static_library, 'Pods', :ios)
          pod_native_target_1 = project.new_target(:static_library, 'Pods-BananaLib', :ios)
          pod_native_target_2 = project.new_target(:static_library, 'Pods-monkey', :ios)

          @aggregate_target = Target.new('Pods')
          @aggregate_target.target = aggregate_native_target
          @pod_target_1 = Target.new('BananaLib', @aggregate_target)
          @pod_target_1.target = pod_native_target_1
          @pod_target_2 = Target.new('monkey', @aggregate_target)
          @pod_target_2.target = pod_native_target_2

          @sut = PodsProjectGenerator.new(config.sandbox, [@aggregate_target])
        end


        it "sets the pod targets as dependencies of the aggregate target" do
          @sut.send(:add_missing_target_dependencies)
          dependencies = @aggregate_target.target.dependencies
          dependencies.map { |d| d.target.name}.should == ["Pods-BananaLib", "Pods-monkey"]
        end

        it "sets the dependencies of the pod targets" do
          @pod_target_1.stubs(:dependencies).returns(['monkey'])
          @pod_target_1.stubs(:pod_name).returns('BananaLib')
          @pod_target_2.stubs(:pod_name).returns('monkey')
          @sut.send(:add_missing_target_dependencies)
          dependencies = @pod_target_1.target.dependencies
          dependencies.map { |d| d.target.name}.should == ["Pods-monkey"]
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
