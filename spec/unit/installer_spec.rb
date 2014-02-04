require File.expand_path('../../spec_helper', __FILE__)

# @return [Lockfile]
#
def generate_lockfile
  hash = {}
  hash['PODS'] = []
  hash['DEPENDENCIES'] = []
  hash['SPEC CHECKSUMS'] = []
  hash['COCOAPODS'] = Pod::VERSION
  Pod::Lockfile.new(hash)
end

# @return [Podfile]
#
def generate_podfile(pods = ['JSONKit'])
  podfile = Pod::Podfile.new do
    platform :ios
    xcodeproj SpecHelper.fixture('SampleProject/SampleProject'), 'Test' => :debug, 'App Store' => :release
    pods.each { |name| pod name }
  end
end

#-----------------------------------------------------------------------------#

module Pod
  describe Installer do

    before do
      podfile = generate_podfile
      lockfile = generate_lockfile
      config.integrate_targets = false
      @installer = Installer.new(config.sandbox, podfile, lockfile)
    end

    #-------------------------------------------------------------------------#

    describe "In general" do

      before do
        @installer.stubs(:resolve_dependencies)
        @installer.stubs(:download_dependencies)
        @installer.stubs(:generate_pods_project)
        @installer.stubs(:integrate_user_project)
      end

      it "in runs the pre-install hooks before cleaning the Pod sources" do
        @installer.unstub(:download_dependencies)
        @installer.stubs(:create_file_accessors)
        @installer.stubs(:install_pod_sources)
        def @installer.run_pre_install_hooks
          @hook_called = true
        end
        def @installer.clean_pod_sources
          @hook_called.should.be.true
        end
        @installer.install!
      end

      it "in runs the post-install hooks before serializing the Pods project" do
        @installer.stubs(:prepare_pods_project)
        @installer.stubs(:run_pre_install_hooks)
        @installer.stubs(:install_file_references)
        @installer.stubs(:install_libraries)
        @installer.stubs(:link_aggregate_target)
        @installer.stubs(:write_lockfiles)
        @installer.stubs(:aggregate_targets).returns([])
        @installer.unstub(:generate_pods_project)
        def @installer.run_post_install_hooks
          @hook_called = true
        end
        def @installer.write_pod_project
          @hook_called.should.be.true
        end
        @installer.install!
      end

      it "integrates the user targets if the corresponding config is set" do
        config.integrate_targets = true
        @installer.expects(:integrate_user_project)
        @installer.install!
      end

      it "doesn't integrates the user targets if the corresponding config is not set" do
        config.integrate_targets = false
        @installer.expects(:integrate_user_project).never
        @installer.install!
      end

    end

    #-------------------------------------------------------------------------#

    describe "Dependencies Resolution" do

      describe "#analyze" do

        it "prints a warning if the version of the Lockfile is higher than the one of the executable" do
          Lockfile.any_instance.stubs(:cocoapods_version).returns(Version.new('999'))
          STDERR.expects(:puts)
          @installer.send(:analyze)
        end

        it "analyzes the Podfile, the Lockfile and the Sandbox" do
          @installer.send(:analyze)
          @installer.analysis_result.sandbox_state.added.should == ["JSONKit"]
        end

        it "stores the targets created by the analyzer" do
          @installer.send(:analyze)
          @installer.aggregate_targets.map(&:name).sort.should == ['Pods']
          @installer.pod_targets.map(&:name).sort.should == ['Pods-JSONKit']
        end

        it "configures the analyzer to use update mode if appropriate" do
          @installer.update_mode = true
          Installer::Analyzer.any_instance.expects(:update_mode=).with(true)
          @installer.send(:analyze)
          @installer.aggregate_targets.map(&:name).sort.should == ['Pods']
          @installer.pod_targets.map(&:name).sort.should == ['Pods-JSONKit']
        end

      end

      #--------------------------------------#

      describe "#validate_whitelisted_configurations" do
        it "raises when a whitelisted configuration doesn’t exist in the user's project" do
          target_definition = @installer.podfile.target_definitions.values.first
          target_definition.whitelist_pod_for_configuration('JSONKit', 'YOLO')
          @installer.send(:analyze)
          should.raise Informative do
            @installer.send(:validate_whitelisted_configurations)
          end
        end

        it "does not raise if all whitelisted configurations exist in the user's project" do
          target_definition = @installer.podfile.target_definitions.values.first
          target_definition.whitelist_pod_for_configuration('JSONKit', 'Test')
          @installer.send(:analyze)
          should.not.raise do
            @installer.send(:validate_whitelisted_configurations)
          end
        end
      end

      #--------------------------------------#

      describe "#clean_sandbox" do

        before do
          @analysis_result = Installer::Analyzer::AnalysisResult.new
          @analysis_result.specifications = []
          @analysis_result.sandbox_state = Installer::Analyzer::SpecsState.new()
          @pod_targets = [PodTarget.new([], nil, config.sandbox)]
          @installer.stubs(:analysis_result).returns(@analysis_result)
          @installer.stubs(:pod_targets).returns(@pod_targets)
        end

        it "cleans the header stores" do
          config.sandbox.public_headers.expects(:implode!)
          @installer.pod_targets.each do |pods_target|
            pods_target.build_headers.expects(:implode!)
          end
          @installer.send(:clean_sandbox)
        end

        it "deletes the sources of the removed Pods" do
          @analysis_result.sandbox_state.add_name('Deleted-Pod', :deleted)
          config.sandbox.expects(:clean_pod).with('Deleted-Pod')
          @installer.send(:clean_sandbox)
        end

      end

    end

    #-------------------------------------------------------------------------#

    describe "Downloading dependencies" do

      describe "#install_pod_sources" do

        it "installs all the Pods which are marked as needing installation" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          spec_2 = Spec.new
          spec_2.name = 'RestKit'
          @installer.stubs(:root_specs).returns([spec, spec_2])
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.added << 'BananaLib'
          sandbox_state.changed << 'RestKit'
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.expects(:install_source_of_pod).with('BananaLib')
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
        end

        it "correctly configures the Pod source installer" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new([spec], nil, config.sandbox)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.expects(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
        end

        it "maintains the list of the installed specs" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new([spec], nil, config.sandbox)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target, pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.stubs(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
          @installer.installed_specs.should == [spec]
        end

        #--------------------------------------#

        describe "#clean" do

          it "it cleans only if the config instructs to do it" do
            config.clean = false
            @installer.send(:clean_pod_sources)
            Installer::PodSourceInstaller.any_instance.expects(:install!).never
          end

        end

        #--------------------------------------#

      end
    end

    #-------------------------------------------------------------------------#

    describe "Generating pods project" do

      describe "#prepare_pods_project" do

        before do
          @installer.stubs(:aggregate_targets).returns([])
        end

        it "creates build configurations for all of the user's targets" do
          config.integrate_targets = true
          @installer.send(:analyze)
          @installer.send(:prepare_pods_project)
          @installer.pods_project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
        end

        it "sets STRIP_INSTALLED_PRODUCT to NO for all configurations for the whole project" do
          config.integrate_targets = true
          @installer.send(:analyze)
          @installer.send(:prepare_pods_project)
          @installer.pods_project.build_settings('Debug')["STRIP_INSTALLED_PRODUCT"].should == "NO"
          @installer.pods_project.build_settings('Test')["STRIP_INSTALLED_PRODUCT"].should == "NO"
          @installer.pods_project.build_settings('Release')["STRIP_INSTALLED_PRODUCT"].should == "NO"
          @installer.pods_project.build_settings('App Store')["STRIP_INSTALLED_PRODUCT"].should == "NO"
        end

        before do
          @installer.stubs(:analysis_result).returns(stub(:all_user_build_configurations => {}))
        end

        it "creates the Pods project" do
          @installer.send(:prepare_pods_project)
          @installer.pods_project.class.should == Pod::Project
        end

        it "adds the Podfile to the Pods project" do
          config.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
          @installer.send(:prepare_pods_project)
          @installer.pods_project['Podfile'].should.be.not.nil
        end

        it "sets the deployment target for the whole project" do
          pod_target_ios = PodTarget.new([], nil, config.sandbox)
          pod_target_osx = PodTarget.new([], nil, config.sandbox)
          pod_target_ios.stubs(:platform).returns(Platform.new(:ios, '6.0'))
          pod_target_osx.stubs(:platform).returns(Platform.new(:osx, '10.8'))
          @installer.stubs(:aggregate_targets).returns([pod_target_ios, pod_target_osx])
          @installer.stubs(:pod_targets).returns([])
          @installer.send(:prepare_pods_project)
          build_settings = @installer.pods_project.build_configurations.map(&:build_settings)
          build_settings.each do |build_setting|
            build_setting["MACOSX_DEPLOYMENT_TARGET"].should == '10.8'
            build_setting["IPHONEOS_DEPLOYMENT_TARGET"].should == '6.0'
          end
        end

      end

      #--------------------------------------#

      describe "#install_file_references" do

        it "installs the file references" do
          @installer.stubs(:pod_targets).returns([])
          Installer::FileReferencesInstaller.any_instance.expects(:install!)
          @installer.send(:install_file_references)
        end

      end

      #--------------------------------------#

      describe "#install_libraries" do

        it "install the targets of the Pod project" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.store_pod('BananaLib')
          pod_target = PodTarget.new([spec], target_definition, config.sandbox)
          @installer.stubs(:aggregate_targets).returns([])
          @installer.stubs(:pod_targets).returns([pod_target])
          Installer::PodTargetInstaller.any_instance.expects(:install!)
          @installer.send(:install_libraries)
        end

        it "skips empty pod targets" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          pod_target = PodTarget.new([spec], target_definition, config.sandbox)
          @installer.stubs(:aggregate_targets).returns([])
          @installer.stubs(:pod_targets).returns([pod_target])
          Installer::PodTargetInstaller.any_instance.expects(:install!).never
          @installer.send(:install_libraries)
        end

        xit 'adds the frameworks required by to the pod to the project for informative purposes' do
          Specification::Consumer.any_instance.stubs(:frameworks).returns(['QuartzCore'])
          @installer.install!
          names = @installer.sandbox.project['Frameworks'].children.map(&:name)
          names.sort.should == ["Foundation.framework", "QuartzCore.framework"]
        end

      end

      #--------------------------------------#

      describe "#set_target_dependencies" do

        xit "sets the pod targets as dependencies of the aggregate target" do

        end

        xit "sets the dependecies of the pod targets" do

        end

        xit "is robusts against subspecs" do

        end

      end

      #--------------------------------------#

      describe "#write_pod_project" do

        before do
          @installer.stubs(:aggregate_targets).returns([])
          @installer.stubs(:analysis_result).returns(stub(:all_user_build_configurations => {}))
          @installer.send(:prepare_pods_project)
        end

        it "recursively sorts the project" do
          @installer.pods_project.main_group.expects(:sort)
          @installer.send(:write_pod_project)
        end

        it "saves the project to the given path" do
          path = temporary_directory + 'Pods/Pods.xcodeproj'
          @installer.pods_project.expects(:save)
          @installer.send(:write_pod_project)
        end

      end

      #--------------------------------------#

      describe "#write_lockfiles" do

        before do
          @analysis_result = Installer::Analyzer::AnalysisResult.new
          @analysis_result.specifications = [fixture_spec('banana-lib/BananaLib.podspec')]
          @installer.stubs(:analysis_result).returns(@analysis_result)
        end

        it "generates the lockfile" do
          @installer.send(:write_lockfiles)
          @installer.lockfile.pod_names.should == ['BananaLib']
        end

        it "writes the lockfile" do
          @installer.send(:write_lockfiles)
          lockfile = Lockfile.from_file(temporary_directory + 'Podfile.lock')
          lockfile.pod_names.should == ['BananaLib']
        end

        it "writes the sandbox manifest" do
          @installer.send(:write_lockfiles)
          lockfile = Lockfile.from_file(temporary_directory + 'Pods/Manifest.lock')
          lockfile.pod_names.should == ['BananaLib']
        end

      end

    end

    #-------------------------------------------------------------------------#

    describe "Integrating client projects" do

      it "integrates the client projects" do
        @installer.stubs(:aggregate_targets).returns([AggregateTarget.new(nil, config.sandbox)])
        Installer::UserProjectIntegrator.any_instance.expects(:integrate!)
        @installer.send(:integrate_user_project)
      end

    end

    #-------------------------------------------------------------------------#

    describe "Hooks" do

      before do
        @installer.send(:analyze)
        @specs = @installer.pod_targets.map(&:specs).flatten
        @spec = @specs.find { |spec| spec && spec.name == 'JSONKit' }
        @installer.stubs(:installed_specs).returns(@specs)
        @aggregate_target = @installer.aggregate_targets.first
      end

      it "runs the pre install hooks" do
        installer_rep = stub()
        pod_rep = stub()
        library_rep = stub()

        @installer.expects(:installer_rep).returns(installer_rep)
        @installer.expects(:pod_rep).with('JSONKit').returns(pod_rep)
        @installer.expects(:library_rep).with(@aggregate_target).returns(library_rep)
        @spec.expects(:pre_install!)
        @installer.podfile.expects(:pre_install!).with(installer_rep)
        @installer.send(:run_pre_install_hooks)
      end

      it "run_post_install_hooks" do
        installer_rep = stub()
        target_installer_data = stub()

        @installer.expects(:installer_rep).returns(installer_rep)
        @installer.expects(:library_rep).with(@aggregate_target).returns(target_installer_data)
        @spec.expects(:post_install!)
        @installer.podfile.expects(:post_install!).with(installer_rep)
        @installer.send(:run_post_install_hooks)
      end

      it "calls the hooks in the specs for each target" do
        pod_target_ios = PodTarget.new([@spec], nil, config.sandbox)
        pod_target_osx = PodTarget.new([@spec], nil, config.sandbox)
        pod_target_ios.stubs(:name).returns('label')
        pod_target_osx.stubs(:name).returns('label')
        library_ios_rep = stub()
        library_osx_rep = stub()
        target_installer_data = stub()

        @installer.stubs(:pod_targets).returns([pod_target_ios, pod_target_osx])
        @installer.stubs(:installer_rep).returns(stub())
        @installer.stubs(:library_rep).with(@aggregate_target).returns(target_installer_data).twice

        @installer.podfile.expects(:pre_install!)
        @spec.expects(:post_install!).with(target_installer_data).once

        @installer.send(:run_pre_install_hooks)
        @installer.send(:run_post_install_hooks)
      end

      it "returns the hook representation of the installer" do
        rep = @installer.send(:installer_rep)
        rep.sandbox_root.should == @installer.sandbox.root
      end

      it "returns the hook representation of a pod" do
        file_accessor = stub(:spec => @spec)
        @aggregate_target.pod_targets.first.stubs(:file_accessors).returns([file_accessor])
        rep = @installer.send(:pod_rep, 'JSONKit')
        rep.name.should == 'JSONKit'
        rep.root_spec.should == @spec
      end

      it "returns the hook representation of an aggregate target" do
        rep = @installer.send(:library_rep, @aggregate_target)
        rep.send(:library).name.should == 'Pods'
      end

      it "returns the hook representation of all the pods" do
        reps = @installer.send(:pod_reps)
        reps.map(&:name).should == ['JSONKit']
      end

      it "returns the hook representation of all the aggregate target" do
        reps = @installer.send(:library_reps)
        reps.map(&:name).sort.should == ['Pods'].sort
      end

      it "returns the aggregate targets which use a given Pod" do
        libs = @installer.send(:libraries_using_spec, @spec)
        libs.map(&:name).should == ['Pods']
      end

    end

  end
end

