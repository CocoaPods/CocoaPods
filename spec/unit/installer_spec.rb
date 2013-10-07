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
        @installer.stubs(:analyze_dependencies)
        @installer.stubs(:download_sources)
        @installer.stubs(:generate_pods_project)
        @installer.stubs(:write_lockfiles)
        @installer.stubs(:integrate_user_project)
      end

      it "in runs the pre-install hooks before cleaning the Pod sources" do
        @installer.unstub(:download_sources)
        @installer.stubs(:create_file_accessors)
        @installer.stubs(:install_pod_sources)
        @installer.stubs(:link_headers)
        @installer.stubs(:refresh_file_accessors)
        def @installer.run_pre_install_hooks
          @hook_called = true
        end
        def @installer.clean_pod_sources
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

    describe "#analyze_dependencies" do

      describe "#analyze" do

        it "prints a warning if the version of the Lockfile is higher than the one of the executable" do
          Lockfile.any_instance.stubs(:cocoapods_version).returns(Version.new('999'))
          STDERR.expects(:puts)
          @installer.send(:analyze)
        end

        it "analyzes the Podfile, the Lockfile and the Sandbox" do
          @installer.send(:analyze)
          config.sandbox.state.added.should == ["JSONKit"]
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

      describe "#clean_sandbox" do

        before do
          @analysis_result = Installer::Analyzer::AnalysisResult.new
          @analysis_result.specifications = []
          config.sandbox.state = Installer::Analyzer::SpecsState.new()
          pod_target = Target.new('BananaLib', nil)
          pod_target.private_headers_store = Sandbox::HeadersStore.new(config.sandbox, "BuildHeaders")
          @pod_targets = [pod_target]

          @installer.stubs(:analysis_result).returns(@analysis_result)
          @installer.stubs(:pod_targets).returns(@pod_targets)
        end

        it "cleans the header stores" do
          config.sandbox.public_headers.expects(:implode!)
          @installer.pod_targets.each do |pods_target|
            pods_target.private_headers_store.expects(:implode!)
          end
          @installer.send(:clean_sandbox)
        end

        it "deletes the sources of the removed Pods" do
          config.sandbox.state.add_name('Deleted-Pod', :deleted)
          config.sandbox.expects(:clean_pod).with('Deleted-Pod')
          @installer.send(:clean_sandbox)
        end

      end

    end

    #-------------------------------------------------------------------------#

    describe "#download_sources" do

      describe "#install_pod_sources" do

        it "installs all the Pods which are marked as needing installation" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          spec_2 = Spec.new
          spec_2.name = 'RestKit'
          @installer.stubs(:root_specs).returns([spec, spec_2])
          config.sandbox.state = Installer::Analyzer::SpecsState.new
          config.sandbox.state.added << 'BananaLib'
          config.sandbox.state.changed << 'RestKit'
          @installer.expects(:install_source_of_pod).with('BananaLib')
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
        end

        it "correctly configures the Pod source installer" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = Target.new('BananaLib')
          pod_target.specs = [spec]
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.expects(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
        end

        it "maintains the list of the installed specs" do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = Target.new('BananaLib')
          pod_target.specs = [spec]
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target, pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.stubs(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
          @installer.installed_specs.should == [spec]
        end

        #--------------------------------------#

        describe "#clean_pod_sources" do

          it "it cleans only if the config instructs to do it" do
            config.clean = false
            Installer::PodSourceInstaller.any_instance.expects(:clean!).never
            @installer.send(:clean_pod_sources)
          end

        end

        #--------------------------------------#

        describe "#refresh_file_accessors" do

          it "refreshes the file accessors after cleaning and executing the specification hooks" do
            pod_target = Target.new('BananaLib')
            file_accessor = stub()
            pod_target.file_accessors = [file_accessor]
            @installer.stubs(:pod_targets).returns([pod_target])
            file_accessor.expects(:refresh)
            @installer.send(:refresh_file_accessors)
          end

        end

        #--------------------------------------#

        describe "#link_headers" do

          before do
            @pod_target = Target.new('BananaLib')
            @pod_target.file_accessors = [fixture_file_accessor('banana-lib/BananaLib.podspec')]
            @pod_target.private_headers_store = Sandbox::HeadersStore.new(config.sandbox, "BuildHeaders")
            @installer.stubs(:pod_targets).returns([@pod_target])
          end

          it "links the build headers" do
            @installer.send(:link_headers)

            headers_root = @pod_target.private_headers_store.root
            public_header =  headers_root + 'BananaLib/Banana.h'
            private_header = headers_root + 'BananaLib/BananaPrivate.h'
            public_header.should.exist
            private_header.should.exist
          end

          it "links the public headers" do
            @installer.send(:link_headers)

            headers_root = config.sandbox.public_headers.root
            public_header =  headers_root + 'BananaLib/Banana.h'
            private_header = headers_root + 'BananaLib/BananaPrivate.h'
            public_header.should.exist
            private_header.should.not.exist
          end

          describe "#header_mappings" do

            before do
              @file_accessor = fixture_file_accessor('banana-lib/BananaLib.podspec')
            end

            it "returns the header mappings" do
              headers_sandbox = Pathname.new('BananaLib')
              headers = [Pathname.new('BananaLib/Banana.h')]
              mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
              mappings.should == {
                headers_sandbox => [Pathname.new('BananaLib/Banana.h')]
              }
            end

            it "takes into account the header dir specified in the spec" do
              headers_sandbox = Pathname.new('BananaLib')
              headers = [Pathname.new('BananaLib/Banana.h')]
              @file_accessor.spec_consumer.stubs(:header_dir).returns('Sub_dir')
              mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
              mappings.should == {
                (headers_sandbox + 'Sub_dir') => [Pathname.new('BananaLib/Banana.h')]
              }
            end

            it "takes into account the header mappings dir specified in the spec" do
              headers_sandbox = Pathname.new('BananaLib')
              header_1 = @file_accessor.root + 'BananaLib/sub_dir/dir_1/banana_1.h'
              header_2 = @file_accessor.root + 'BananaLib/sub_dir/dir_2/banana_2.h'
              headers = [ header_1, header_2 ]
              @file_accessor.spec_consumer.stubs(:header_mappings_dir).returns('BananaLib/sub_dir')
              mappings = @installer.send(:header_mappings, headers_sandbox, @file_accessor, headers)
              mappings.should == {
                (headers_sandbox + 'dir_1') => [header_1],
                (headers_sandbox + 'dir_2') => [header_2],
              }
            end

          end
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe "#generate_pods_project" do

      before do
        analysis_result = Installer::Analyzer::AnalysisResult.new
        analysis_result.specifications = []
        analysis_result.stubs(:all_user_build_configurations).returns({})
        @installer.stubs(:analysis_result).returns(analysis_result)
        @installer.stubs(:aggregate_targets).returns([])
      end

      it "generates the Pods project" do
        Installer::PodsProjectGenerator.any_instance.expects(:install)
        Installer::PodsProjectGenerator.any_instance.expects(:write_project)
        @installer.send(:generate_pods_project)
      end

      it "in runs the post-install hooks before serializing the Pods project" do
        Installer::PodsProjectGenerator.any_instance.expects(:install)
        def @installer.run_post_install_hooks
          Installer::PodsProjectGenerator.any_instance.expects(:write_project)
        end
        @installer.send(:generate_pods_project)
      end

    end

    #-------------------------------------------------------------------------#

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

    #-------------------------------------------------------------------------#

    describe "#integrate_user_project" do

      it "integrates the client projects" do
        @installer.stubs(:aggregate_targets).returns([Target.new('Pods')])
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

      it "runs the post install hooks" do
        installer_rep = stub()
        target_installer_data = stub()

        @installer.expects(:installer_rep).returns(installer_rep)
        @installer.expects(:library_rep).with(@aggregate_target).returns(target_installer_data)
        @spec.expects(:post_install!)
        @installer.podfile.expects(:post_install!).with(installer_rep)
        @installer.send(:run_post_install_hooks)
      end

      it "calls the hooks in the specs for each target" do
        pod_target_ios = Target.new('ios-BananaLib')
        pod_target_osx = Target.new('osx-BananaLib')

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
        @aggregate_target.children.first.stubs(:file_accessors).returns([file_accessor])
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

