require File.expand_path('../../spec_helper', __FILE__)

require 'cocoapods_stats/sender'

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
  Pod::Podfile.new do
    platform :ios
    xcodeproj SpecHelper.fixture('SampleProject/SampleProject'), 'Test' => :debug, 'App Store' => :release
    pods.each { |name| pod name }
  end
end

# @return [Podfile]
#
def generate_local_podfile
  Pod::Podfile.new do
    platform :ios
    xcodeproj SpecHelper.fixture('SampleProject/SampleProject'), 'Test' => :debug, 'App Store' => :release
    pod 'Reachability', :path => SpecHelper.fixture('integration/Reachability')
  end
end

#-----------------------------------------------------------------------------#

module Pod
  describe Installer do
    before do
      CocoaPodsStats::Sender.any_instance.stubs(:send)
      podfile = generate_podfile
      lockfile = generate_lockfile
      config.integrate_targets = false
      @installer = Installer.new(config.sandbox, podfile, lockfile)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      before do
        @installer.stubs(:resolve_dependencies)
        @installer.stubs(:download_dependencies)
        @installer.stubs(:determine_dependency_product_types)
        @installer.stubs(:verify_no_duplicate_framework_names)
        @installer.stubs(:verify_no_static_framework_transitive_dependencies)
        @installer.stubs(:verify_framework_usage)
        @installer.stubs(:generate_pods_project)
        @installer.stubs(:integrate_user_project)
        @installer.stubs(:run_plugins_post_install_hooks)
        @installer.stubs(:ensure_plugins_are_installed!)
        @installer.stubs(:perform_post_install_actions)
      end

      it 'in runs the pre-install hooks before cleaning the Pod sources' do
        @installer.unstub(:download_dependencies)
        @installer.stubs(:create_file_accessors)
        @installer.stubs(:install_pod_sources)
        def @installer.run_podfile_pre_install_hooks
          @hook_called = true
        end
        def @installer.clean_pod_sources
          @hook_called.should.be.true
        end
        @installer.install!
      end

      it 'in runs the post-install hooks before serializing the Pods project' do
        @installer.stubs(:prepare_pods_project)
        @installer.stubs(:run_podfile_pre_install_hooks)
        @installer.stubs(:install_file_references)
        @installer.stubs(:install_libraries)
        @installer.stubs(:set_target_dependencies)
        @installer.stubs(:write_lockfiles)
        @installer.stubs(:aggregate_targets).returns([])
        @installer.unstub(:generate_pods_project)
        def @installer.run_podfile_post_install_hooks
          @hook_called = true
        end
        def @installer.write_pod_project
          @hook_called.should.be.true
        end
        @installer.install!
      end

      it 'runs source provider hooks before analyzing' do
        config.skip_repo_update = true
        @installer.unstub(:resolve_dependencies)
        @installer.stubs(:validate_build_configurations)
        @installer.stubs(:prepare_for_legacy_compatibility)
        @installer.stubs(:clean_sandbox)
        def @installer.run_source_provider_hooks
          @hook_called = true
        end
        def @installer.analyze(*)
          @hook_called.should.be.true
        end
        @installer.install!
      end

      it 'includes sources from source provider plugins' do
        plugin_name = 'test-plugin'
        Pod::HooksManager.register(plugin_name, :source_provider) do |context, options|
          source_url = options['sources'].first
          return unless source_url
          source = Pod::Source.new(source_url)
          context.add_source(source)
        end

        test_source_name = 'https://github.com/artsy/Specs.git'
        plugins_hash = Installer::DEFAULT_PLUGINS.merge(plugin_name => { 'sources' => [test_source_name] })
        @installer.podfile.stubs(:plugins).returns(plugins_hash)
        @installer.unstub(:resolve_dependencies)
        @installer.stubs(:validate_build_configurations)
        @installer.stubs(:prepare_for_legacy_compatibility)
        @installer.stubs(:clean_sandbox)
        @installer.stubs(:ensure_plugins_are_installed!)
        @installer.stubs(:analyze)
        config.skip_repo_update = true

        analyzer = Installer::Analyzer.new(config.sandbox, @installer.podfile, @installer.lockfile)
        analyzer.stubs(:analyze)
        @installer.stubs(:create_analyzer).returns(analyzer)
        @installer.install!

        source = Pod::Source.new(test_source_name)
        names = analyzer.sources.map(&:name)
        names.should.include(source.name)
      end

      it 'integrates the user targets if the corresponding config is set' do
        config.integrate_targets = true
        @installer.expects(:integrate_user_project)
        @installer.install!
      end

      it "doesn't integrates the user targets if the corresponding config is not set" do
        config.integrate_targets = false
        @installer.expects(:integrate_user_project).never
        @installer.install!
      end

      it 'prints a list of deprecated pods' do
        spec = Spec.new
        spec.name = 'RestKit'
        spec.deprecated_in_favor_of = 'AFNetworking'
        spec_two = Spec.new
        spec_two.name = 'BlocksKit'
        spec_two.deprecated = true
        @installer.stubs(:root_specs).returns([spec, spec_two])
        @installer.send(:warn_for_deprecations)
        UI.warnings.should.include 'deprecated in favor of AFNetworking'
        UI.warnings.should.include 'BlocksKit has been deprecated'
      end
    end

    #-------------------------------------------------------------------------#

    describe '#determine_dependency_product_type' do
      it 'does propagate that frameworks are required to all pod targets' do
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([])
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        podfile = Pod::Podfile.new do
          platform :ios, '8.0'
          xcodeproj 'SampleProject/SampleProject'
          use_frameworks!
          pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
          pod 'monkey',          :path => (fixture_path + 'monkey').to_s

          target 'TestRunner', :exclusive => true do
            pod 'monkey',        :path => (fixture_path + 'monkey').to_s
          end
        end
        lockfile = generate_lockfile
        config.integrate_targets = false

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.install!

        target = @installer.aggregate_targets.first
        target.requires_frameworks?.should == true
        target.pod_targets.select(&:requires_frameworks?).map(&:name).sort.should == %w(
          BananaLib
          OrangeFramework
          monkey
        )
      end
    end

    #-------------------------------------------------------------------------#

    describe '#verify_no_duplicate_framework_names' do
      it 'detects duplicate framework names' do
        Sandbox::FileAccessor.any_instance.stubs(:vendored_frameworks).returns([Pathname('monkey.framework')])
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        podfile = Pod::Podfile.new do
          platform :ios, '8.0'
          xcodeproj 'SampleProject/SampleProject'
          pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
          pod 'monkey',          :path => (fixture_path + 'monkey').to_s
        end
        lockfile = generate_lockfile
        config.integrate_targets = false

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        should.raise(Informative) { @installer.install! }.message.should.match /conflict.*monkey/
      end
    end

    #-------------------------------------------------------------------------#

    describe '#verify_no_static_framework_transitive_dependencies' do
      before do
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        config.integrate_targets = false
        @podfile = Pod::Podfile.new do
          platform :ios, '8.0'
          xcodeproj 'SampleProject/SampleProject'
          use_frameworks!
          pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
          pod 'monkey',          :path => (fixture_path + 'monkey').to_s
        end
        @lockfile = generate_lockfile
      end

      it 'detects transitive static dependencies which are linked directly to the user target' do
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([Pathname('/libThing.a')])
        @installer = Installer.new(config.sandbox, @podfile, @lockfile)
        should.raise(Informative) { @installer.install! }.message.should.match /transitive.*libThing/
      end

      it 'allows transitive static dependencies which contain other source code' do
        Sandbox::FileAccessor.any_instance.stubs(:source_files).returns([Pathname('/yolo.m')])
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([Pathname('/libThing.a')])
        @installer = Installer.new(config.sandbox, @podfile, @lockfile)
        should.not.raise(Informative) { @installer.install! }
      end

      it 'allows transitive static dependencies when both dependencies are linked against the user target' do
        PodTarget.any_instance.stubs(:should_build? => false)
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([Pathname('/libThing.a')])
        @installer = Installer.new(config.sandbox, @podfile, @lockfile)
        should.not.raise(Informative) { @installer.install! }
      end
    end

    #-------------------------------------------------------------------------#

    describe '#verify_framework_usage' do
      it 'raises when Swift pods are used without explicit `use_frameworks!`' do
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        podfile = Pod::Podfile.new do
          platform :ios, '8.0'
          xcodeproj 'SampleProject/SampleProject'
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
        end
        lockfile = generate_lockfile
        config.integrate_targets = false

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        should.raise(Informative) { @installer.install! }.message.should.match /use_frameworks/
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Dependencies Resolution' do
      describe 'updating spec repos' do
        it 'does not updates the repositories if config indicates to skip them' do
          config.skip_repo_update = true
          SourcesManager.expects(:update).never
          @installer.send(:resolve_dependencies)
        end

        it 'updates the repositories by default' do
          config.skip_repo_update = false
          SourcesManager.expects(:update).once
          @installer.send(:resolve_dependencies)
        end
      end

      #--------------------------------------#

      describe '#analyze' do
        it 'prints a warning if the version of the Lockfile is higher than the one of the executable' do
          Lockfile.any_instance.stubs(:cocoapods_version).returns(Version.new('999'))
          STDERR.expects(:puts)
          @installer.send(:analyze)
        end

        it 'analyzes the Podfile, the Lockfile and the Sandbox' do
          @installer.send(:analyze)
          @installer.analysis_result.sandbox_state.added.should == ['JSONKit']
        end

        it 'stores the targets created by the analyzer' do
          @installer.send(:analyze)
          @installer.aggregate_targets.map(&:name).sort.should == ['Pods']
          @installer.pod_targets.map(&:name).sort.should == ['JSONKit']
        end

        it 'configures the analyzer to use update mode if appropriate' do
          @installer.update = true
          Installer::Analyzer.any_instance.expects(:update=).with(true)
          @installer.send(:analyze)
          @installer.aggregate_targets.map(&:name).sort.should == ['Pods']
          @installer.pod_targets.map(&:name).sort.should == ['JSONKit']
        end
      end

      #--------------------------------------#

      describe '#validate_whitelisted_configurations' do
        it "raises when a whitelisted configuration doesn’t exist in the user's project" do
          target_definition = @installer.podfile.target_definitions.values.first
          target_definition.whitelist_pod_for_configuration('JSONKit', 'YOLO')
          @installer.send(:analyze)
          should.raise Informative do
            @installer.send(:validate_build_configurations)
          end
        end

        it "does not raise if all whitelisted configurations exist in the user's project" do
          target_definition = @installer.podfile.target_definitions.values.first
          target_definition.whitelist_pod_for_configuration('JSONKit', 'Test')
          @installer.send(:analyze)
          should.not.raise do
            @installer.send(:validate_build_configurations)
          end
        end
      end

      #--------------------------------------#

      describe '#clean_sandbox' do
        before do
          @analysis_result = Installer::Analyzer::AnalysisResult.new
          @analysis_result.specifications = []
          @analysis_result.sandbox_state = Installer::Analyzer::SpecsState.new
          @pod_targets = [PodTarget.new([stub('Spec')], [stub('TargetDefinition')], config.sandbox)]
          @installer.stubs(:analysis_result).returns(@analysis_result)
          @installer.stubs(:pod_targets).returns(@pod_targets)
        end

        it 'cleans the header stores' do
          config.sandbox.public_headers.expects(:implode!)
          @installer.pod_targets.each do |pods_target|
            pods_target.build_headers.expects(:implode!)
          end
          @installer.send(:clean_sandbox)
        end

        it 'deletes the sources of the removed Pods' do
          @analysis_result.sandbox_state.add_name('Deleted-Pod', :deleted)
          config.sandbox.expects(:clean_pod).with('Deleted-Pod')
          @installer.send(:clean_sandbox)
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Downloading dependencies' do
      it 'installs head pods' do
        podfile = Podfile.new do
          platform :osx, '10.10'
          pod 'CargoBay', '2.1.0'
          pod 'AFNetworking/NSURLSession', :head
        end
        @installer.stubs(:podfile).returns(podfile)
        @installer.stubs(:lockfile).returns(nil)
        Downloader::Git.any_instance.expects(:download).once
        Downloader::Git.any_instance.expects(:download_head).once
        Downloader::Git.any_instance.stubs(:checkout_options).returns({})
        @installer.prepare
        @installer.resolve_dependencies
        @installer.send(:root_specs).sort_by(&:name).map(&:version).map(&:head?).should == [true, nil]
        @installer.download_dependencies
        UI.output.should.include 'HEAD based on 2.4.1'
      end

      describe '#install_pod_sources' do
        it 'installs all the Pods which are marked as needing installation' do
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

        it 'correctly configures the Pod source installer' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new([spec], [stub('TargetDefinition')], config.sandbox)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.expects(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
        end

        it 'maintains the list of the installed specs' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new([spec], [stub('TargetDefinition')], config.sandbox)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target, pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.stubs(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
          @installer.installed_specs.should == [spec]
        end

        it 'prints the previous version of a pod while updating the spec' do
          spec = Spec.new
          spec.name = 'RestKit'
          spec.version = '2.0'
          manifest = Lockfile.new({})
          manifest.stubs(:version).with('RestKit').returns('1.0')
          @installer.sandbox.stubs(:manifest).returns(manifest)
          @installer.stubs(:root_specs).returns([spec])
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.changed << 'RestKit'
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
          UI.output.should.include 'was 1.0'
        end

        #--------------------------------------#

        describe '#clean' do
          it 'it cleans only if the config instructs to do it' do
            config.clean = false
            @installer.send(:clean_pod_sources)
            Installer::PodSourceInstaller.any_instance.expects(:install!).never
          end
        end

        #--------------------------------------#
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Generating pods project' do
      describe '#prepare_pods_project' do
        before do
          @installer.stubs(:aggregate_targets).returns([])
        end

        it "creates build configurations for all of the user's targets" do
          config.integrate_targets = true
          @installer.send(:analyze)
          @installer.send(:prepare_pods_project)
          @installer.pods_project.build_configurations.map(&:name).sort.should == ['App Store', 'Debug', 'Release', 'Test']
        end

        it 'sets STRIP_INSTALLED_PRODUCT to NO for all configurations for the whole project' do
          config.integrate_targets = true
          @installer.send(:analyze)
          @installer.send(:prepare_pods_project)
          @installer.pods_project.build_settings('Debug')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
          @installer.pods_project.build_settings('Test')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
          @installer.pods_project.build_settings('Release')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
          @installer.pods_project.build_settings('App Store')['STRIP_INSTALLED_PRODUCT'].should == 'NO'
        end

        before do
          @installer.stubs(:analysis_result).returns(stub(:all_user_build_configurations => {}))
        end

        it 'creates the Pods project' do
          @installer.send(:prepare_pods_project)
          @installer.pods_project.class.should == Pod::Project
        end

        it 'preserves Pod paths specified as absolute or rooted to home' do
          local_podfile = generate_local_podfile
          local_installer = Installer.new(config.sandbox, local_podfile)
          local_installer.send(:analyze)
          local_installer.send(:prepare_pods_project)
          group = local_installer.pods_project.group_for_spec('Reachability')
          Pathname.new(group.path).should.be.absolute
        end

        it 'adds the Podfile to the Pods project' do
          config.stubs(:podfile_path).returns(Pathname.new('/Podfile'))
          @installer.send(:prepare_pods_project)
          @installer.pods_project['Podfile'].should.be.not.nil
        end

        it 'sets the deployment target for the whole project' do
          pod_target_ios = PodTarget.new([stub('Spec')], [stub('TargetDefinition')], config.sandbox)
          pod_target_osx = PodTarget.new([stub('Spec')], [stub('TargetDefinition')], config.sandbox)
          pod_target_ios.stubs(:platform).returns(Platform.new(:ios, '6.0'))
          pod_target_osx.stubs(:platform).returns(Platform.new(:osx, '10.8'))
          aggregate_target_ios = AggregateTarget.new(nil, config.sandbox)
          aggregate_target_osx = AggregateTarget.new(nil, config.sandbox)
          aggregate_target_ios.stubs(:platform).returns(Platform.new(:ios, '6.0'))
          aggregate_target_osx.stubs(:platform).returns(Platform.new(:osx, '10.8'))
          @installer.stubs(:aggregate_targets).returns([aggregate_target_ios, aggregate_target_osx])
          @installer.stubs(:pod_targets).returns([])
          @installer.send(:prepare_pods_project)
          build_settings = @installer.pods_project.build_configurations.map(&:build_settings)
          build_settings.each do |build_setting|
            build_setting['MACOSX_DEPLOYMENT_TARGET'].should == '10.8'
            build_setting['IPHONEOS_DEPLOYMENT_TARGET'].should == '6.0'
          end
        end
      end

      #--------------------------------------#

      describe '#install_file_references' do
        it 'installs the file references' do
          @installer.stubs(:pod_targets).returns([])
          Installer::FileReferencesInstaller.any_instance.expects(:install!)
          @installer.send(:install_file_references)
        end
      end

      #--------------------------------------#

      describe '#install_libraries' do
        it 'install the targets of the Pod project' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          target_definition.store_pod('BananaLib')
          pod_target = PodTarget.new([spec], [target_definition], config.sandbox)
          @installer.stubs(:aggregate_targets).returns([])
          @installer.stubs(:pod_targets).returns([pod_target])
          Installer::PodTargetInstaller.any_instance.expects(:install!)
          @installer.send(:install_libraries)
        end

        it 'skips empty pod targets' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          target_definition = Podfile::TargetDefinition.new(:default, nil)
          pod_target = PodTarget.new([spec], [target_definition], config.sandbox)
          @installer.stubs(:aggregate_targets).returns([])
          @installer.stubs(:pod_targets).returns([pod_target])
          Installer::PodTargetInstaller.any_instance.expects(:install!).never
          @installer.send(:install_libraries)
        end

        xit 'adds the frameworks required by to the pod to the project for informative purposes' do
          Specification::Consumer.any_instance.stubs(:frameworks).returns(['QuartzCore'])
          @installer.install!
          names = @installer.sandbox.project['Frameworks'].children.map(&:name)
          names.sort.should == ['Foundation.framework', 'QuartzCore.framework']
        end
      end

      #--------------------------------------#

      describe '#set_target_dependencies' do
        def test_extension_target(symbol_type)
          mock_user_target = mock('UserTarget', :symbol_type => symbol_type)
          @target.stubs(:user_targets).returns([mock_user_target])

          build_settings = {}
          mock_configuration = mock('BuildConfiguration', :build_settings => build_settings)
          @mock_target.stubs(:build_configurations).returns([mock_configuration])

          @installer.send(:set_target_dependencies)

          build_settings.should == { 'APPLICATION_EXTENSION_API_ONLY' => 'YES' }
        end

        before do
          spec = fixture_spec('banana-lib/BananaLib.podspec')

          target_definition = Podfile::TargetDefinition.new(:default, @installer.podfile)
          @pod_target = PodTarget.new([spec], [target_definition], config.sandbox)
          @target = AggregateTarget.new(target_definition, config.sandbox)

          @mock_target = mock('PodNativeTarget')

          mock_project = mock('PodsProject', :frameworks_group => mock('FrameworksGroup'))
          @installer.stubs(:pods_project).returns(mock_project)

          @target.stubs(:native_target).returns(@mock_target)
          @target.stubs(:pod_targets).returns([@pod_target])
          @installer.stubs(:aggregate_targets).returns([@target])
        end

        it 'sets resource bundles for not build pods as target dependencies of the user target' do
          @pod_target.stubs(:resource_bundle_targets).returns(['dummy'])
          @pod_target.stubs(:should_build? => false)
          @mock_target.expects(:add_dependency).with('dummy')

          @installer.send(:set_target_dependencies)
        end

        it 'configures APPLICATION_EXTENSION_API_ONLY for app extension targets' do
          test_extension_target(:app_extension)
        end

        it 'configures APPLICATION_EXTENSION_API_ONLY for watch extension targets' do
          test_extension_target(:watch_extension)
        end

        it 'configures APPLICATION_EXTENSION_API_ONLY for watchOS 2 extension targets' do
          test_extension_target(:watch2_extension)
        end

        it 'does not try to set APPLICATION_EXTENSION_API_ONLY if there are no pod targets' do
          lambda do
            mock_user_target = mock('UserTarget', :symbol_type => :app_extension)
            @target.stubs(:user_targets).returns([mock_user_target])

            @target.stubs(:native_target).returns(nil)
            @target.stubs(:pod_targets).returns([])

            @installer.send(:set_target_dependencies)
          end.should.not.raise NoMethodError
        end

        xit 'sets the pod targets as dependencies of the aggregate target' do
        end

        xit 'sets the dependecies of the pod targets' do
        end

        xit 'is robusts against subspecs' do
        end
      end

      #--------------------------------------#

      describe '#write_pod_project' do
        before do
          @installer.stubs(:aggregate_targets).returns([])
          @installer.stubs(:analysis_result).returns(stub(:all_user_build_configurations => {}))
          @installer.send(:prepare_pods_project)
        end

        it 'recursively sorts the project' do
          Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
          @installer.pods_project.main_group.expects(:sort)
          @installer.send(:write_pod_project)
        end

        it 'saves the project to the given path' do
          Xcodeproj::Project.any_instance.stubs(:recreate_user_schemes)
          temporary_directory + 'Pods/Pods.xcodeproj'
          @installer.pods_project.expects(:save)
          @installer.send(:write_pod_project)
        end

        it 'shares schemes of development pods' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = fixture_pod_target(spec)

          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.sandbox.stubs(:development_pods).returns('BananaLib' => nil)

          Xcodeproj::XCScheme.expects(:share_scheme).with(
            @installer.pods_project.path,
            'BananaLib')

          @installer.send(:share_development_pod_schemes)
        end

        it "uses the user project's object version for the pods project" do
          tmp_directory = Pathname(Dir.tmpdir) + 'CocoaPods'
          FileUtils.mkdir_p(tmp_directory)
          proj = Xcodeproj::Project.new(tmp_directory + 'Yolo.xcodeproj', false, 1)
          proj.save

          aggregate_target = AggregateTarget.new(nil, config.sandbox)
          aggregate_target.stubs(:platform).returns(Platform.new(:ios, '6.0'))
          aggregate_target.stubs(:user_project_path).returns(proj.path)
          @installer.stubs(:aggregate_targets).returns([aggregate_target])

          @installer.send(:prepare_pods_project)
          @installer.pods_project.object_version.should == '1'

          FileUtils.rm_rf(tmp_directory)
        end
      end

      #--------------------------------------#

      describe '#write_lockfiles' do
        before do
          @analysis_result = Installer::Analyzer::AnalysisResult.new
          @analysis_result.specifications = [fixture_spec('banana-lib/BananaLib.podspec')]
          @installer.stubs(:analysis_result).returns(@analysis_result)
        end

        it 'generates the lockfile' do
          @installer.send(:write_lockfiles)
          @installer.lockfile.pod_names.should == ['BananaLib']
        end

        it 'writes the lockfile' do
          @installer.send(:write_lockfiles)
          lockfile = Lockfile.from_file(temporary_directory + 'Podfile.lock')
          lockfile.pod_names.should == ['BananaLib']
        end

        it 'writes the sandbox manifest' do
          @installer.send(:write_lockfiles)
          lockfile = Lockfile.from_file(temporary_directory + 'Pods/Manifest.lock')
          lockfile.pod_names.should == ['BananaLib']
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Integrating client projects' do
      it 'integrates the client projects' do
        @installer.stubs(:aggregate_targets).returns([AggregateTarget.new(nil, config.sandbox)])
        Installer::UserProjectIntegrator.any_instance.expects(:integrate!)
        @installer.send(:integrate_user_project)
      end
    end

    describe 'Plugins Hooks' do
      before do
        @installer.send(:analyze)
        @specs = @installer.pod_targets.map(&:specs).flatten
        @spec = @specs.find { |spec| spec && spec.name == 'JSONKit' }
        @installer.stubs(:installed_specs).returns(@specs)
      end

      describe 'DEFAULT_PLUGINS' do
        before do
          @default_plugins = @installer.send(:plugins)
        end

        it 'includes cocoapods-stats' do
          @default_plugins['cocoapods-stats'].should == {}
        end
      end

      it 'runs plugins pre install hook' do
        context = stub
        Installer::PreInstallHooksContext.expects(:generate).returns(context)
        HooksManager.expects(:run).with(:pre_install, context, Installer::DEFAULT_PLUGINS)
        @installer.send(:run_plugins_pre_install_hooks)
      end

      it 'runs plugins post install hook' do
        context = stub
        Installer::PostInstallHooksContext.expects(:generate).returns(context)
        HooksManager.expects(:run).with(:post_install, context, Installer::DEFAULT_PLUGINS)
        @installer.send(:run_plugins_post_install_hooks)
      end

      it 'runs plugins source provider hook' do
        context = stub
        context.stubs(:sources).returns([])
        Installer::SourceProviderHooksContext.expects(:generate).returns(context)
        HooksManager.expects(:run).with(:source_provider, context, Installer::DEFAULT_PLUGINS)
        @installer.send(:run_source_provider_hooks)
      end

      it 'only runs the podfile-specified hooks' do
        context = stub
        Installer::PostInstallHooksContext.expects(:generate).returns(context)
        plugins_hash = Installer::DEFAULT_PLUGINS.merge('cocoapods-keys' => { 'keyring' => 'Eidolon' })
        @installer.podfile.stubs(:plugins).returns(plugins_hash)
        HooksManager.expects(:run).with(:post_install, context, plugins_hash)
        @installer.send(:run_plugins_post_install_hooks)
      end

      it 'raises if a podfile-specified plugin is not loaded' do
        @installer.podfile.stubs(:plugins).returns('cocoapods-keys' => {})
        Command::PluginManager.stubs(:specifications).returns([])
        should.raise Informative do
          @installer.send(:ensure_plugins_are_installed!)
        end.message.should.match /require.*plugin.*`cocoapods-keys`/
      end

      it 'does not raise if all podfile-specified plugins are loaded' do
        @installer.podfile.stubs(:plugins).returns('cocoapods-keys' => {})
        spec = stub
        spec.stubs(:name).returns('cocoapods-keys')
        Command::PluginManager.stubs(:specifications).returns([spec])
        should.not.raise do
          @installer.send(:ensure_plugins_are_installed!)
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Podfile Hooks' do
      before do
        podfile = Pod::Podfile.new do
          platform :ios
        end
        config.integrate_targets = false
        @installer = Installer.new(config.sandbox, podfile)
      end

      it 'runs the pre install hooks' do
        @installer.podfile.expects(:pre_install!).with(@installer)
        @installer.install!
      end

      it 'runs the post install hooks' do
        @installer.podfile.expects(:post_install!).with(@installer)
        @installer.install!
      end
    end
  end
end
