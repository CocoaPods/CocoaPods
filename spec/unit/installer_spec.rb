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
    xcodeproj 'SampleProject/SampleProject'
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
        @installer.stubs(:install_targets)
        @installer.stubs(:write_lockfiles)
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

        it "stores the libraries created by the analyzer" do
          @installer.send(:analyze)
          @installer.libraries.map(&:name).should == ['Pods']
        end

        it "configures the analizer to use update mode if appropriate" do
          @installer.update_mode = true
          Installer::Analyzer.any_instance.expects(:update_mode=).with(true)
          @installer.send(:analyze)
          @installer.libraries.map(&:name).should == ['Pods']
        end

      end

      #--------------------------------------#

      describe "#clean_sandbox" do

        before do
          @analysis_result = Installer::Analyzer::AnalysisResult.new
          @analysis_result.specifications = []
          @analysis_result.sandbox_state = Installer::Analyzer::SpecsState.new()
          @installer.stubs(:analysis_result).returns(@analysis_result)
        end

        it "cleans the header stores" do
          config.sandbox.build_headers.expects(:implode!)
          config.sandbox.public_headers.expects(:implode!)
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
          library = Library.new(nil)
          library.specs = [spec]
          library.platform = :ios
          @installer.stubs(:libraries).returns([library])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.expects(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
        end

        it "maintains the list of the installed specs" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          library = Library.new(nil)
          library.specs = [spec]
          @installer.stubs(:libraries).returns([library, library])
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

        it "creates the Pods project" do
          @installer.stubs(:libraries).returns([])
          @installer.send(:prepare_pods_project)
          @installer.pods_project.class.should == Pod::Project
        end

        it "adds the Podfile to the Pods project" do
          @installer.stubs(:libraries).returns([])
          config.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
          @installer.send(:prepare_pods_project)
          f = @installer.pods_project['Podfile']
          f.name.should == 'Podfile'
        end

        it "sets the deployment target for the whole project" do
          library_ios = Library.new(nil)
          library_osx = Library.new(nil)
          library_ios.platform = Platform.new(:ios, '6.0')
          library_osx.platform = Platform.new(:osx, '10.8')
          @installer.stubs(:libraries).returns([library_ios, library_osx])
          @installer.send(:prepare_pods_project)
          build_settings = @installer.pods_project.build_configurations.map(&:build_settings)
          build_settings.should == [
            {"MACOSX_DEPLOYMENT_TARGET"=>"10.8", "IPHONEOS_DEPLOYMENT_TARGET"=>"6.0"},
            {"MACOSX_DEPLOYMENT_TARGET"=>"10.8", "IPHONEOS_DEPLOYMENT_TARGET"=>"6.0"},
          ]
        end
      end

      #--------------------------------------#

      describe "#install_file_references" do

        it "installs the file references" do
          Installer::FileReferencesInstaller.any_instance.expects(:install!)
          @installer.send(:install_file_references)
        end

      end

      #--------------------------------------#

      describe "#install_targets" do

        it "install the targets of the Pod project" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.store_pod('BananaLib')
          library = Library.new(target_definition)
          library.specs = [spec]
          @installer.stubs(:libraries).returns([library])
          Installer::TargetInstaller.any_instance.expects(:install!)
          @installer.send(:install_targets)
        end

        it "skips empty libraries" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          library = Library.new(target_definition)
          library.specs = [spec]
          @installer.stubs(:libraries).returns([library])
          Installer::TargetInstaller.any_instance.expects(:install!).never
          @installer.send(:install_targets)
        end

      end

      #--------------------------------------#

      describe "#write_pod_project" do

        before do
          @installer.stubs(:libraries).returns([])
          @installer.send(:prepare_pods_project)
        end

        it "sorts the main group" do
          @installer.pods_project.main_group.expects(:sort_by_type!)
          @installer.send(:write_pod_project)
        end

        it "sorts the frameworks group" do
          @installer.pods_project['Frameworks'].expects(:sort_by_type!)
          @installer.send(:write_pod_project)
        end

        it "saves the project to the given path" do
          path = temporary_directory + 'Pods/Generated/Pods.xcodeproj'
          @installer.pods_project.expects(:save_as).with(path)
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
          lockfile = Lockfile.from_file(temporary_directory + 'Pods/Generated/Manifest.lock')
          lockfile.pod_names.should == ['BananaLib']
        end

      end

    end

    #-------------------------------------------------------------------------#

    describe "Integrating client projects" do

      it "integrates the client projects" do
        @installer.stubs(:libraries).returns([Library.new(nil)])
        Installer::UserProjectIntegrator.any_instance.expects(:integrate!)
        @installer.send(:integrate_user_project)
      end

    end

    #-------------------------------------------------------------------------#

    describe "Hooks" do

      before do
        @installer.send(:analyze)
        @specs = @installer.libraries.map(&:specs).flatten
        @spec = @specs.find { |spec| spec.name == 'JSONKit' }
        @installer.stubs(:installed_specs).returns(@specs)
        @lib = @installer.libraries.first
      end

      it "runs the pre install hooks" do
        installer_rep = stub()
        pod_rep = stub()
        library_rep = stub()

        @installer.expects(:installer_rep).returns(installer_rep)
        @installer.expects(:pod_rep).with('JSONKit').returns(pod_rep)
        @installer.expects(:library_rep).with(@lib).returns(library_rep)
        @spec.expects(:pre_install!)
        @installer.podfile.expects(:pre_install!).with(installer_rep)
        @installer.send(:run_pre_install_hooks)
      end

      it "run_post_install_hooks" do
        installer_rep = stub()
        target_installer_data = stub()

        @installer.expects(:installer_rep).returns(installer_rep)
        @installer.expects(:library_rep).with(@lib).returns(target_installer_data)
        @spec.expects(:post_install!)
        @installer.podfile.expects(:post_install!).with(installer_rep)
        @installer.send(:run_post_install_hooks)
      end

      it "calls the hooks in the specs for each target" do
        library_ios = Library.new(nil)
        library_osx = Library.new(nil)
        library_ios.specs = [@spec]
        library_osx.specs = [@spec]
        library_ios.stubs(:name).returns('label')
        library_osx.stubs(:name).returns('label')
        library_ios_rep = stub()
        library_osx_rep = stub()

        @installer.stubs(:libraries).returns([library_ios, library_osx])
        @installer.stubs(:installer_rep).returns(stub())
        @installer.stubs(:library_rep).with(library_ios).returns(library_ios_rep)
        @installer.stubs(:library_rep).with(library_osx).returns(library_osx_rep)

        @installer.podfile.expects(:pre_install!)
        @spec.expects(:post_install!).with(library_ios_rep)
        @spec.expects(:post_install!).with(library_osx_rep)

        @installer.send(:run_pre_install_hooks)
        @installer.send(:run_post_install_hooks)
      end

      it "returns the hook representation of the installer" do
        rep = @installer.send(:installer_rep)
        rep.sandbox_root.should == @installer.sandbox.root
      end

      it "returns the hook representation of a pod" do
        file_accessor = stub(:spec => @spec)
        @lib.stubs(:file_accessors).returns([file_accessor])
        rep = @installer.send(:pod_rep, 'JSONKit')
        rep.name.should == 'JSONKit'
        rep.root_spec.should == @spec
      end

      it "returns the hook representation of a library" do
        rep = @installer.send(:library_rep, @lib)
        rep.send(:library).name.should == 'Pods'
      end

      it "returns the hook representation of all the pods" do
        reps = @installer.send(:pod_reps)
        reps.map(&:name).should == ['JSONKit']
      end

      it "returns the hook representation of all the target installers" do
        reps = @installer.send(:library_reps)
        reps.map(&:name).should == ['Pods']
      end

      it "returns the libraries which use a given Pod" do
        libs = @installer.send(:libraries_using_spec, @spec)
        libs.map(&:name).should == ['Pods']
      end

    end

  end
end

