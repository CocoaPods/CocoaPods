require File.expand_path('../../spec_helper', __FILE__)

require 'cocoapods_stats/sender'

# @return [Lockfile]
#
def generate_lockfile(lockfile_version: Pod::VERSION)
  hash = {}
  hash['PODS'] = []
  hash['DEPENDENCIES'] = []
  hash['SPEC CHECKSUMS'] = {}
  hash['COCOAPODS'] = lockfile_version
  Pod::Lockfile.new(hash)
end

# @return [Podfile]
#
def generate_podfile(pods = ['JSONKit'])
  Pod::Podfile.new do
    platform :ios
    project SpecHelper.fixture('SampleProject/SampleProject'), 'Test' => :debug, 'App Store' => :release
    target 'SampleProject' do
      pods.each { |name| pod name }
      target 'SampleProjectTests' do
        inherit! :search_paths
      end
    end
  end
end

# @return [Podfile]
#
def generate_local_podfile
  Pod::Podfile.new do
    platform :ios
    project SpecHelper.fixture('SampleProject/SampleProject'), 'Test' => :debug, 'App Store' => :release
    target 'SampleProject' do
      pod 'Reachability', :path => SpecHelper.fixture('integration/Reachability')
      target 'SampleProjectTests' do
        inherit! :search_paths
      end
    end
  end
end

#-----------------------------------------------------------------------------#

module Pod
  describe Installer do
    before do
      CocoaPodsStats::Sender.any_instance.stubs(:send)
      podfile = generate_podfile
      lockfile = generate_lockfile
      @installer = Installer.new(config.sandbox, podfile, lockfile)
      @installer.installation_options.integrate_targets = false
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      before do
        @installer.stubs(:resolve_dependencies)
        @installer.stubs(:download_dependencies)
        @installer.stubs(:verify_no_duplicate_framework_and_library_names)
        @installer.stubs(:verify_no_static_framework_transitive_dependencies)
        @installer.stubs(:verify_framework_usage)
        @installer.stubs(:generate_pods_project)
        @installer.stubs(:integrate_user_project)
        @installer.stubs(:run_plugins_post_install_hooks)
        @installer.stubs(:ensure_plugins_are_installed!)
        @installer.stubs(:perform_post_install_actions)
        Installer::Xcode::PodsProjectGenerator.any_instance.stubs(:share_development_pod_schemes)
        Installer::Xcode::PodsProjectGenerator.any_instance.stubs(:generate!)
        Installer::Xcode::PodsProjectGenerator.any_instance.stubs(:write)
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
        @installer.stubs(:run_podfile_pre_install_hooks)
        @installer.stubs(:write_lockfiles)
        @installer.stubs(:aggregate_targets).returns([])
        @installer.unstub(:generate_pods_project)
        generator = @installer.send(:create_generator)
        @installer.stubs(:create_generator).returns(generator)
        generator.stubs(:generate!)
        generator.stubs(:share_development_pod_schemes)

        hooks = sequence('hooks')
        @installer.expects(:run_podfile_post_install_hooks).once.in_sequence(hooks)
        generator.expects(:write).once.in_sequence(hooks)

        @installer.install!
      end

      it 'runs source provider hooks before analyzing' do
        @installer.unstub(:resolve_dependencies)
        @installer.stubs(:validate_build_configurations)
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
        @installer.stubs(:clean_sandbox)
        @installer.stubs(:ensure_plugins_are_installed!)
        @installer.stubs(:analyze)

        analyzer = Installer::Analyzer.new(config.sandbox, @installer.podfile, @installer.lockfile)
        analyzer.stubs(:analyze)
        @installer.stubs(:create_analyzer).returns(analyzer)
        @installer.install!

        source = Pod::Source.new(test_source_name)
        names = analyzer.sources.map(&:name)
        names.should.include(source.name)
      end

      it 'performs framework transitive dependencies check if corresponding config is set' do
        @installer.installation_options.integrate_targets = true
        @installer.expects(:verify_no_static_framework_transitive_dependencies)
        @installer.install!
      end

      it 'skips framework transitive dependencies check if corresponding config is not set' do
        @installer.installation_options.integrate_targets = false
        @installer.expects(:verify_no_static_framework_transitive_dependencies).never
        @installer.install!
        UI.warnings.should.include 'Skipping Verifying Framework Transitive Dependencies Check'
      end

      it 'integrates the user targets if the corresponding config is set' do
        @installer.installation_options.integrate_targets = true
        @installer.expects(:integrate_user_project)
        @installer.install!
      end

      it "doesn't integrates the user targets if the corresponding config is not set" do
        @installer.installation_options.integrate_targets = false
        @installer.expects(:integrate_user_project).never
        @installer.install!
        UI.output.should.include 'Skipping User Project Integration'
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

      it 'does not raise if command is run outside sandbox directory' do
        Dir.chdir(@installer.sandbox.root.parent) do
          should.not.raise(Informative) { @installer.install! }
        end
      end

      it 'raises if command is run in sandbox directory' do
        Dir.chdir(@installer.sandbox.root) do
          should.raise Informative do
            @installer.install!
          end.message.should.match /should.*run.*outside.*Pods directory.*Current directory.*\./m
        end
      end

      describe 'handling CocoaPods version updates' do
        it 'does not deintegrate when there is no lockfile' do
          installer = Pod::Installer.new(config.sandbox, generate_podfile, nil)
          UI.expects(:section).never
          installer.send(:deintegrate_if_different_major_version)
        end

        it 'does not deintegrate when the major version is the same' do
          should_not_deintegrate = %w(1.0.0 1.0.1 1.1.0 1.2.2)
          should_not_deintegrate.each do |version|
            lockfile = generate_lockfile(:lockfile_version => version)
            installer = Pod::Installer.new(config.sandbox, generate_podfile, lockfile)
            Pathname.expects(:glob).never
            installer.send(:deintegrate_if_different_major_version)
          end
        end

        it 'does deintegrate when the major version is different' do
          should_not_deintegrate = %w(0.39.0 2.0.0 10.0-beta)
          should_not_deintegrate.each do |version|
            lockfile = generate_lockfile(:lockfile_version => version)
            installer = Pod::Installer.new(config.sandbox, generate_podfile, lockfile)
            project = fixture('SampleProject/SampleProject.xcodeproj')
            Pathname.expects(:glob).with(config.installation_root + '*.xcodeproj').returns([project])
            Deintegrator.any_instance.expects(:deintegrate_project)
            installer.send(:deintegrate_if_different_major_version)
          end
        end
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
          project 'SampleProject/SampleProject'
          use_frameworks!
          pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
          pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
          pod 'monkey',          :path => (fixture_path + 'monkey').to_s

          target 'SampleProject'
          target 'TestRunner' do
            inherit! :search_paths
            pod 'monkey', :path => (fixture_path + 'monkey').to_s
          end
        end
        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.installation_options.integrate_targets = false
        @installer.install!

        target = @installer.aggregate_targets.first
        target.requires_frameworks?.should == true
        target.pod_targets.select(&:requires_frameworks?).map(&:name).sort.should == %w(
          BananaLib
          OrangeFramework
          matryoshka
          monkey
        )
      end
    end

    #-------------------------------------------------------------------------#

    describe '#verify_no_duplicate_framework_and_library_names' do
      it 'detects duplicate library names' do
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([Pathname('a/libBananalib.a')])
        Pod::Specification.any_instance.stubs(:dependencies).returns([])
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        podfile = Pod::Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          pod 'BananaLib', :path => (fixture_path + 'banana-lib').to_s
          target 'SampleProject'
        end
        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.installation_options.integrate_targets = false
        should.raise(Informative) { @installer.install! }.message.should.match /conflict.*bananalib/
      end

      it 'detects duplicate framework names' do
        Sandbox::FileAccessor.any_instance.stubs(:vendored_frameworks).
          returns([Pathname('a/monkey.framework')]).then.
          returns([Pathname('b/monkey.framework')]).then.
          returns([Pathname('c/monkey.framework')])
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        podfile = Pod::Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
          pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
          pod 'monkey',          :path => (fixture_path + 'monkey').to_s
          target 'SampleProject'
        end
        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.installation_options.integrate_targets = false
        should.raise(Informative) { @installer.install! }.message.should.match /conflict.*monkey/
      end

      it 'allows duplicate references to the same expanded framework path' do
        Sandbox::FileAccessor.any_instance.stubs(:vendored_frameworks).returns([fixture('monkey/dynamic-monkey.framework')])
        Sandbox::FileAccessor.any_instance.stubs(:dynamic_binary?).returns(true)
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        podfile = Pod::Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          use_frameworks!
          pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
          pod 'monkey',          :path => (fixture_path + 'monkey').to_s
          target 'SampleProject'
        end
        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.installation_options.integrate_targets = false
        should.not.raise(Informative) { @installer.install! }
      end
    end

    #-------------------------------------------------------------------------#

    describe '#verify_no_static_framework_transitive_dependencies' do
      before do
        fixture_path = ROOT + 'spec/fixtures'
        config.repos_dir = fixture_path + 'spec-repos'
        @podfile = Pod::Podfile.new do
          install! 'cocoapods', 'integrate_targets' => false
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          use_frameworks!
          pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
          pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
          pod 'monkey',          :path => (fixture_path + 'monkey').to_s
          target 'SampleProject'
        end
        @lockfile = generate_lockfile

        @file = Pathname('/yolo.m')
        @file.stubs(:realpath).returns(@file)

        @lib_thing = Pathname('/libThing.a')
        @lib_thing.stubs(:realpath).returns(@lib_thing)
      end

      it 'detects transitive static dependencies which are linked directly to the user target' do
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
        @installer = Installer.new(config.sandbox, @podfile, @lockfile)
        @installer.installation_options.integrate_targets = true
        should.raise(Informative) { @installer.install! }.message.should.match /transitive.*libThing/
      end

      it 'allows transitive static dependencies which contain other source code' do
        Sandbox::FileAccessor.any_instance.stubs(:source_files).returns([@file])
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
        @installer = Installer.new(config.sandbox, @podfile, @lockfile)
        @installer.installation_options.integrate_targets = true
        should.not.raise(Informative) { @installer.install! }
      end

      it 'allows transitive static dependencies when both dependencies are linked against the user target' do
        PodTarget.any_instance.stubs(:should_build? => false)
        Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
        @installer = Installer.new(config.sandbox, @podfile, @lockfile)
        @installer.installation_options.integrate_targets = true
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
          project 'SampleProject/SampleProject'
          pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
          pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
          target 'SampleProject'
        end
        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.installation_options.integrate_targets = false
        should.raise(Informative) { @installer.install! }.message.should.match /use_frameworks/
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Dependencies Resolution' do
      describe 'updating spec repos' do
        it 'does not updates the repositories by default' do
          config.sources_manager.expects(:update).never
          @installer.send(:resolve_dependencies)
        end

        it 'updates the repositories if that was requested' do
          @installer.repo_update = true
          config.sources_manager.expects(:update).once
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
          @installer.analysis_result.sandbox_state.added.should == Set.new(%w(JSONKit))
        end

        it 'stores the targets created by the analyzer' do
          @installer.send(:analyze)
          @installer.aggregate_targets.map(&:name).sort.should == ['Pods-SampleProject', 'Pods-SampleProjectTests']
          @installer.pod_targets.map(&:name).sort.should == ['JSONKit']
        end

        it 'configures the analyzer to use update mode if appropriate' do
          @installer.update = true
          Installer::Analyzer.any_instance.expects(:update=).with(true)
          @installer.send(:analyze)
          @installer.aggregate_targets.map(&:name).sort.should == ['Pods-SampleProject', 'Pods-SampleProjectTests']
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
          @pod_targets = [PodTarget.new([stub('Spec')], [fixture_target_definition], config.sandbox)]
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
          pod_target = PodTarget.new([spec], [fixture_target_definition], config.sandbox)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.expects(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
        end

        it 'maintains the list of the installed specs' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new([spec], [fixture_target_definition], config.sandbox)
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

        it 'raises when it attempts to install pod source with no target supporting it' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new([spec], [fixture_target_definition], config.sandbox)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target])
          should.raise Informative do
            @installer.send(:create_pod_installer, 'RandomPod')
          end.message.should.include 'Could not install \'RandomPod\' pod. There is no target that supports it.'
        end

        #--------------------------------------#

        describe '#clean' do
          it 'it cleans only if the config instructs to do it' do
            @installer.installation_options.clean = false
            @installer.send(:clean_pod_sources)
            Installer::PodSourceInstaller.any_instance.expects(:install!).never
          end
        end

        #--------------------------------------#
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Generating pods project' do
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
        @installer.stubs(:aggregate_targets).returns([AggregateTarget.new(fixture_target_definition, config.sandbox)])
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
        @installer = Installer.new(config.sandbox, podfile)
        @installer.installation_options.integrate_targets = false
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
