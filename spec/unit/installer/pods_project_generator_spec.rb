require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Installer
    describe PodsProjectGenerator do

      #-----------------------------------------------------------------------#

      describe "In general" do

        before do
          @sut = PodsProjectGenerator.new(config.sandbox, [])
        end

        it "performs an installation" do
          @sut.send(:install)
          @sut.project.should.not.be.nil
        end

        it "can write the pods project" do
          @sut.send(:install)
          @sut.project.expects(:save)
          @sut.send(:write_pod_project)
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

        it "creates a group for each Pod" do
          pod_target = PodTarget.new([], nil, config.sandbox)
          pod_target.stubs(:pod_name).returns('BananaLib')
          @sut.stubs(:pod_targets).returns([pod_target])
          @sut.send(:prepare_project)
          @sut.project['Pods/BananaLib'].should.not.be.nil
        end

        it "creates a group for each development Pod" do
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
          target_ios = AggregateTarget.new(nil, config.sandbox)
          target_osx = AggregateTarget.new(nil, config.sandbox)
          target_ios.stubs(:platform).returns(Platform.new(:ios, '6.0'))
          target_osx.stubs(:platform).returns(Platform.new(:osx, '10.8'))
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

        it "installs the file references" do
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
          aggregate_target = AggregateTarget.new(@target_definition, config.sandbox)
          aggregate_target.pod_targets = [pod_target]
          @sut = PodsProjectGenerator.new(config.sandbox, [aggregate_target])
        end

        it "install the aggregate targets" do
          @target_definition.store_pod('BananaLib')
          Installer::PodsProjectGenerator::PodTargetInstaller.any_instance.stubs(:install!)
          Installer::PodsProjectGenerator::AggregateTargetInstaller.any_instance.expects(:install!)
          @sut.send(:install_targets)
        end

        it "install the Pod targets" do
          @target_definition.store_pod('BananaLib')
          Installer::PodsProjectGenerator::AggregateTargetInstaller.any_instance.stubs(:install!)
          Installer::PodsProjectGenerator::PodTargetInstaller.any_instance.expects(:install!)
          @sut.send(:install_targets)
        end

        it "skips empty targets" do
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

        it 'adds the frameworks required by to the pod to the project for informative purposes' do
          Project.any_instance.expects(:add_system_framework).with('QuartzCore', @pod_native_target)
          @sut.send(:install_system_frameworks)
        end
      end

      #-----------------------------------------------------------------------#

      describe "#set_target_dependencies" do

        before do
          project = Pod::Project.new(config.sandbox.project_path)
          aggregate_native_target = project.new_target(:static_library, 'Pods', :ios)
          pod_native_target_1 = project.new_target(:static_library, 'Pods-BananaLib', :ios)
          @pod_target_1 = PodTarget.new([], nil, config.sandbox)
          @pod_target_1.stubs(:pod_name).returns('BananaLib')
          @pod_target_1.target = pod_native_target_1
          pod_native_target_2 = project.new_target(:static_library, 'Pods-monkey', :ios)
          pod_target_2 = PodTarget.new([], nil, config.sandbox)
          pod_target_2.stubs(:pod_name).returns('monkey')
          pod_target_2.target = pod_native_target_2
          @aggregate_target = AggregateTarget.new(nil, config.sandbox)
          @aggregate_target.pod_targets = [@pod_target_1, pod_target_2]
          @aggregate_target.target = aggregate_native_target
          @sut = PodsProjectGenerator.new(config.sandbox, [@aggregate_target])
        end


        it "sets the pod targets as dependencies of the aggregate target" do
          @sut.send(:set_target_dependencies)
          dependencies = @aggregate_target.target.dependencies
          dependencies.map { |d| d.target.name}.should == ["Pods-BananaLib", "Pods-monkey"]
        end

        it "sets the dependencies of the pod targets" do
          @pod_target_1.stubs(:dependencies).returns(['monkey'])
          @sut.send(:set_target_dependencies)
          dependencies = @pod_target_1.target.dependencies
          dependencies.map { |d| d.target.name}.should == ["Pods-monkey"]
        end

      end

      #-----------------------------------------------------------------------#

      describe "#link_aggregate_target" do

        before do
          project = Pod::Project.new(config.sandbox.project_path)
          @aggregate_native_target = project.new_target(:static_library, 'Pods', :ios)
          @pod_native_target = project.new_target(:static_library, 'Pods-BananaLib', :ios)
          pod_target = PodTarget.new([], nil, config.sandbox)
          pod_target.target = @pod_native_target
          aggregate_target = AggregateTarget.new(nil, config.sandbox)
          aggregate_target.pod_targets = [pod_target]
          aggregate_target.target = @aggregate_native_target
          @sut = PodsProjectGenerator.new(config.sandbox, [aggregate_target])
        end

        it "links the aggregate targets to the pod targets" do
          @sut.send(:link_aggregate_target)
          @aggregate_native_target.frameworks_build_phase.files.map(&:file_ref).should.include?(@pod_native_target.product_reference)
        end

      end

      #-----------------------------------------------------------------------#

      describe "#clean_up_project" do

        before do
          @sut = PodsProjectGenerator.new(config.sandbox, [])
          @sut.install
        end

        it "removes the Pods group if empty" do
          @sut.send(:write_pod_project)
          @sut.project['Pods'].should.be.nil
        end

        it "removes the Development Pods group if empty" do
          @sut.send(:write_pod_project)
          @sut.project['Development Pods'].should.be.nil
        end

        it "recursively sorts the project by type" do
          @sut.project.main_group.expects(:recursively_sort_by_type)
          @sut.send(:write_pod_project)
        end

      end

      #-----------------------------------------------------------------------#

    end
  end
end
