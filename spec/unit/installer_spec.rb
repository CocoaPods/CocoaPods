require File.expand_path('../../spec_helper', __FILE__)

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
def generate_podfile(pods = ['DfPodTest'])
  Pod::Podfile.new do
    platform :ios, 8.0
    install! 'cocoapods', :integrate_targets => false
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
      pod 'Reachability', :path => SpecHelper.fixture('integration/Reachability').to_s
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
      podfile = generate_podfile
      lockfile = generate_lockfile
      @installer = Installer.new(config.sandbox, podfile, lockfile)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      before do
        @installer.stubs(:resolve_dependencies)
        @installer.stubs(:download_dependencies)
        @installer.stubs(:validate_targets)
        @installer.stubs(:stage_sandbox)
        @installer.stubs(:clean_sandbox)
        @installer.stubs(:generate_pods_project)
        @installer.stubs(:integrate_user_project)
        @installer.stubs(:run_plugins_post_install_hooks)
        @installer.stubs(:ensure_plugins_are_installed!)
        @installer.stubs(:perform_post_install_actions)
        @installer.stubs(:predictabilize_uuids)
        @installer.stubs(:stabilize_target_uuids)
        podfile_dependency_cache = Installer::Analyzer::PodfileDependencyCache.from_podfile(@installer.podfile)
        @analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {}, {},
                                                                   [fixture_spec('banana-lib/BananaLib.podspec')],
                                                                   Pod::Installer::Analyzer::SpecsState.new, [], [],
                                                                   podfile_dependency_cache)
        @installer.stubs(:analysis_result).returns(@analysis_result)
        Installer::Xcode::PodsProjectGenerator.any_instance.stubs(:configure_schemes)
        Installer::Xcode::SinglePodsProjectGenerator.any_instance.stubs(:generate!)
        Installer::Xcode::PodsProjectWriter.any_instance.stubs(:write!)
      end

      it 'in runs the pre-install hooks before cleaning the Pod sources' do
        @installer.unstub(:download_dependencies)
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
        @installer.stubs(:pod_targets).returns([])
        analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {}, {},
                                                                  [], Pod::Installer::Analyzer::SpecsState.new, [], [],
                                                                  Installer::Analyzer::PodfileDependencyCache.from_podfile(@installer.podfile))
        @installer.stubs(:analysis_result).returns(analysis_result)
        @installer.unstub(:generate_pods_project)
        generator = @installer.send(:create_generator, [], [], {}, '')
        @installer.stubs(:create_generator).returns(generator)
        target_installation_results = Installer::Xcode::PodsProjectGenerator::InstallationResults.new({}, {})
        generator_result = Installer::Xcode::PodsProjectGenerator::PodsProjectGeneratorResult.new(nil, {}, target_installation_results)
        generator.stubs(:generate!).returns(generator_result)
        generator.stubs(:configure_schemes)
        Installer::Xcode::PodsProjectWriter.any_instance.unstub(:write!)

        hooks = sequence('hooks')
        @installer.expects(:run_podfile_post_install_hooks).once.in_sequence(hooks)
        Installer::Xcode::PodsProjectWriter.any_instance.expects(:save_projects).once.in_sequence(hooks)

        @installer.install!
      end

      it 'injects all generated projects into #share_development_pod_schemes for single project generation' do
        @installer.unstub(:generate_pods_project)
        Installer::SandboxDirCleaner.any_instance.stubs(:clean!)
        @installer.stubs(:pod_targets).returns([])
        @installer.stubs(:aggregate_targets).returns([])

        analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {}, {},
                                                                  [], Pod::Installer::Analyzer::SpecsState.new, [], [],
                                                                  Installer::Analyzer::PodfileDependencyCache.from_podfile(@installer.podfile))
        @installer.stubs(:analysis_result).returns(analysis_result)

        generator = @installer.send(:create_generator, [], [], {}, '')
        @installer.stubs(:create_generator).returns(generator)

        target_installation_results = Installer::Xcode::PodsProjectGenerator::InstallationResults.new({}, {})
        pods_project = fixture('Pods.xcodeproj')
        generator_result = Installer::Xcode::PodsProjectGenerator::PodsProjectGeneratorResult.new(pods_project, {}, target_installation_results)
        generator.stubs(:generate!).returns(generator_result)
        generator.expects(:configure_schemes).once

        @installer.install!
      end

      it 'injects all generated projects into #share_development_pod_schemes for multi project generation' do
        @installer.unstub(:generate_pods_project)
        Installer::SandboxDirCleaner.any_instance.stubs(:clean!)

        @installer.stubs(:pod_targets).returns([])
        @installer.stubs(:aggregate_targets).returns([])

        analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {}, {},
                                                                  [], Pod::Installer::Analyzer::SpecsState.new, [], [],
                                                                  Installer::Analyzer::PodfileDependencyCache.from_podfile(@installer.podfile))
        @installer.stubs(:analysis_result).returns(analysis_result)

        generator = @installer.send(:create_generator, @pod_targets, [], {}, '', true)
        @installer.stubs(:create_generator).returns(generator)

        target_installation_results = Installer::Xcode::PodsProjectGenerator::InstallationResults.new({}, {})
        pods_project = fixture('Pods.xcodeproj')
        projects_by_pod_targets = { fixture('Subproject.xcodeproj') => [] }
        generator_result = Installer::Xcode::PodsProjectGenerator::PodsProjectGeneratorResult.new(pods_project, projects_by_pod_targets, target_installation_results)
        generator.stubs(:generate!).returns(generator_result)
        generator.expects(:configure_schemes).twice

        @installer.install!
      end

      describe 'UUID handling' do
        before do
          @installer.unstub(:generate_pods_project)
          Installer::SandboxDirCleaner.any_instance.stubs(:clean!)
          @installer.stubs(:pod_targets).returns([])
          @installer.stubs(:aggregate_targets).returns([])

          analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {}, {},
                                                                    [], Pod::Installer::Analyzer::SpecsState.new, [], [],
                                                                    Installer::Analyzer::PodfileDependencyCache.from_podfile(@installer.podfile))
          @installer.stubs(:analysis_result).returns(analysis_result)

          generator = @installer.send(:create_generator, [], [], {}, '')
          @installer.stubs(:create_generator).returns(generator)

          target_installation_results = Installer::Xcode::PodsProjectGenerator::InstallationResults.new({}, {})
          pods_project = fixture('Pods.xcodeproj')
          generator_result = Installer::Xcode::PodsProjectGenerator::PodsProjectGeneratorResult.new(pods_project, {}, target_installation_results)
          generator.stubs(:generate!).returns(generator_result)
        end

        it 'predictabilizes UUIDs if the corresponding config is true' do
          @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new)
          @installer.expects(:predictabilize_uuids).with([fixture('Pods.xcodeproj')]).once

          @installer.install!
        end

        it "doesn't predictabilize UUIDs if the corresponding config is false" do
          @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new(:deterministic_uuids => false))
          @installer.expects(:create_and_save_projects).once
          @installer.expects(:predictabilize_uuids).never

          @installer.install!
        end

        it 'stabilizes target UUIDs' do
          @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new)
          @installer.expects(:stabilize_target_uuids).with([fixture('Pods.xcodeproj')]).once

          @installer.install!
        end
      end

      describe 'handling spec sources' do
        before do
          @hooks_manager = Pod::HooksManager
          @hooks_manager.instance_variable_set(:@registrations, nil)
        end

        it 'runs source provider hooks before analyzing' do
          @installer.unstub(:resolve_dependencies)
          @installer.stubs(:validate_build_configurations)
          @installer.stubs(:clean_sandbox)
          @installer.stubs(:analyze)
          @installer.stubs(:run_source_provider_hooks).with do
            @hook_called = true
          end
          @installer.install!
          @hook_called.should.be.true
        end

        it 'includes sources from source provider plugins' do
          plugin_name = 'test-plugin'
          @hooks_manager.register(plugin_name, :source_provider) do |context, options|
            source_url = options['sources'].first
            return unless source_url
            source = Pod::Source.new(source_url)
            context.add_source(source)
          end

          test_source_name = 'https://github.com/artsy/CustomSpecs.git'
          plugins_hash = Installer::DEFAULT_PLUGINS.merge(plugin_name => { 'sources' => [test_source_name] })
          @installer.podfile.stubs(:plugins).returns(plugins_hash)
          @installer.unstub(:resolve_dependencies)
          @installer.stubs(:validate_build_configurations)
          @installer.stubs(:clean_sandbox)
          @installer.stubs(:analyze)
          Installer::Analyzer.any_instance.stubs(:update_repositories)

          analyzer = @installer.resolve_dependencies

          source = Pod::Source.new(test_source_name)
          names = analyzer.sources.map(&:name)
          names.should.include(source.name)
        end

        it 'does not automatically add master spec repo if plugin sources exist' do
          plugin_name = 'test-plugin'
          @hooks_manager.register(plugin_name, :source_provider) do |context, options|
            source_url = options['sources'].first
            return unless source_url
            source = Pod::Source.new(source_url)
            context.add_source(source)
          end

          test_source_name = 'https://github.com/artsy/CustomSpecs.git'
          plugins_hash = Installer::DEFAULT_PLUGINS.merge(plugin_name => { 'sources' => [test_source_name] })
          @installer.podfile.stubs(:plugins).returns(plugins_hash)
          @installer.unstub(:resolve_dependencies)
          @installer.stubs(:validate_build_configurations)
          @installer.stubs(:clean_sandbox)
          @installer.stubs(:analyze)
          Installer::Analyzer.any_instance.stubs(:update_repositories)

          analyzer = @installer.resolve_dependencies
          names = analyzer.sources.map(&:name)
          names.should == [Pod::Source.new('https://github.com/artsy/CustomSpecs.git').name]
        end
      end

      it 'installs Pods from plugin sources' do
        path = fixture('SampleProject/SampleProject')
        podfile = Podfile.new do
          install! 'cocoapods', :integrate_targets => false
          project path

          plugin 'my-plugin'

          target 'SampleProject' do
            platform :ios, '10.0'
            pod 'CoconutLib'
            pod 'monkey'
          end
        end
        podfile.stubs(:plugins).returns('my-plugin' => {})

        plugin_source = Pod::Source.new(fixture('spec-repos/test_repo'))

        Pod::HooksManager.register('my-plugin', :source_provider) do |context, _|
          context.add_source(plugin_source)
        end

        @installer = Installer.new(config.sandbox, podfile, generate_lockfile)
        @installer.stubs(:ensure_plugins_are_installed!)
        @installer.resolve_dependencies
        @installer.analysis_result.pod_targets.map(&:name).sort.should == %w(CoconutLib monkey)
      end

      it 'integrates the user targets if the corresponding config is set' do
        @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new(:integrate_targets => true))
        @installer.expects(:integrate_user_project)
        @installer.install!
      end

      it "doesn't integrates the user targets if the corresponding config is not set" do
        @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new(:integrate_targets => false))
        @installer.expects(:integrate_user_project).never
        @installer.install!
        UI.output.should.include 'Skipping User Project Integration'
      end

      it "doesn't generate Pods.xcodeproj if skip_pods_project_generation is true" do
        @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new(:skip_pods_project_generation => true))
        @installer.expects(:integrate).never
        @installer.install!
        UI.output.should.include 'Skipping Pods Project Creation'
        UI.output.should.include 'Skipping User Project Integration'
      end

      it 'generates Pods.xcodeproj if skip_pods_project_generation is not set' do
        @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new)
        @installer.expects(:integrate).once
        @installer.install!
      end

      it 'always writes lockfile even if project generation and integration is false' do
        installation_options = Pod::Installer::InstallationOptions.new(:skip_pods_project_generation => true, :integrate_targets => false)
        @installer.stubs(:installation_options).returns(installation_options)
        @installer.expects(:write_lockfiles)
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

      it 'prints a warning if the master specs repo is not explicitly used but it exists in the users repos dir' do
        podfile = Pod::Podfile.new do
          install! 'cocoapods', :integrate_targets => false
          platform :ios
        end
        @installer = Installer.new(config.sandbox, podfile)
        master_source = Source.new(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        master_source.stubs(:url).returns(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        config.sources_manager.stubs(:all).returns([master_source])
        @installer.send(:warn_for_removing_git_master_specs_repo)
        UI.warnings.should.include 'Your project does not explicitly specify the CocoaPods master specs repo. Since CDN is now used as the' \
          ' default, you may safely remove it from your repos directory via `pod repo remove master`.' \
          ' To suppress this warning please add `warn_for_unused_master_specs_repo => false` to your Podfile.'
      end

      it 'does not print a warning if the master specs repo is explicitly used' do
        podfile = Pod::Podfile.new do
          source Pod::Installer::MASTER_SPECS_REPO_GIT_URL
          install! 'cocoapods', :integrate_targets => false
          platform :ios
        end
        @installer = Installer.new(config.sandbox, podfile)
        master_source = Source.new(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        master_source.stubs(:url).returns(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        config.sources_manager.stubs(:all).returns([master_source])
        @installer.send(:warn_for_removing_git_master_specs_repo)
        UI.warnings.should.be.empty
      end

      it 'does not print a warning if the master specs repo is explicitly used by a plugin' do
        podfile = Pod::Podfile.new do
          plugin 'my-plugin'
          install! 'cocoapods', :integrate_targets => false
          platform :ios
        end
        podfile.stubs(:plugins).returns('my-plugin' => {})

        Pod::HooksManager.register('my-plugin', :source_provider) do |context, _|
          plugin_source = Source.new(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
          plugin_source.stubs(:url).returns(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
          context.add_source(plugin_source)
        end

        @installer = Installer.new(config.sandbox, podfile)
        @installer.stubs(:ensure_plugins_are_installed!)
        master_source = Source.new(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        master_source.stubs(:url).returns(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        config.sources_manager.stubs(:all).returns([master_source])
        @installer.send(:warn_for_removing_git_master_specs_repo)
        UI.warnings.should.be.empty
      end

      it 'does not print a warning if the master specs repo is not explicitly used but is also not present in the users repo dir' do
        podfile = Pod::Podfile.new do
          install! 'cocoapods', :integrate_targets => false
          platform :ios
        end
        @installer = Installer.new(config.sandbox, podfile)
        config.sources_manager.stubs(:all).returns([])
        @installer.send(:warn_for_removing_git_master_specs_repo)
        UI.warnings.should.be.empty
      end

      it 'does not print a warning for removing the master specs repo if the warning is suppressed' do
        podfile = Pod::Podfile.new do
          install! 'cocoapods', :integrate_targets => false, :warn_for_unused_master_specs_repo => false
          platform :ios
        end
        @installer = Installer.new(config.sandbox, podfile)
        master_source = Source.new(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        master_source.stubs(:url).returns(Pod::Installer::MASTER_SPECS_REPO_GIT_URL)
        config.sources_manager.stubs(:all).returns([master_source])
        @installer.send(:warn_for_removing_git_master_specs_repo)
        UI.warnings.should.be.empty
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

          install! 'cocoapods', :integrate_targets => false

          target 'SampleProject'
          target 'TestRunner' do
            inherit! :search_paths
            pod 'monkey', :path => (fixture_path + 'monkey').to_s
          end
        end
        podfile.target_definitions['SampleProject'].stubs(:swift_version).returns('3.0')

        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
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

    describe 'Dependencies Resolution' do
      describe 'updating spec repos' do
        it 'does not update the repositories by default' do
          FileUtils.mkdir_p(config.sandbox.target_support_files_root)
          config.sources_manager.expects(:update).never
          @installer.send(:resolve_dependencies)
        end

        it 'updates the repositories if that was requested' do
          FileUtils.mkdir_p(config.sandbox.target_support_files_root)
          @installer.repo_update = true
          Source::Manager.any_instance.expects(:update).once
          @installer.send(:resolve_dependencies)
        end

        it 'raises when in deployment mode and the podfile has changes' do
          @installer.deployment = true
          should.raise Informative do
            @installer.install!
          end.message.should.include 'There were changes to the podfile in deployment mode'
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
          @installer.analysis_result.sandbox_state.added.should == Set.new(%w(DfPodTest FMDB))
        end

        it 'stores the targets created by the analyzer' do
          @installer.send(:analyze)
          @installer.aggregate_targets.map(&:name).sort.should == ['Pods-SampleProject', 'Pods-SampleProjectTests']
          @installer.pod_targets.map(&:name).sort.should == %w(DfPodTest FMDB)
        end

        it 'configures the analyzer to use update mode if appropriate' do
          @installer.update = true
          analyzer = @installer.send(:create_analyzer)
          analyzer.pods_to_update.should.be.true
        end
      end

      #--------------------------------------#

      describe '#validate_whitelisted_configurations' do
        it "raises when a whitelisted configuration doesn’t exist in the user's project" do
          target_definition = @installer.podfile.target_definitions.values.first
          target_definition.whitelist_pod_for_configuration('DfPodTest', 'YOLO')
          @installer.send(:analyze)
          should.raise Informative do
            @installer.send(:validate_build_configurations)
          end
        end

        it "does not raise if all whitelisted configurations exist in the user's project" do
          target_definition = @installer.podfile.target_definitions.values.first
          target_definition.whitelist_pod_for_configuration('DfPodTest', 'Test')
          @installer.send(:analyze)
          should.not.raise do
            @installer.send(:validate_build_configurations)
          end
        end
      end

      #--------------------------------------#

      describe '#clean_sandbox' do
        before do
          @analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {}, {},
                                                                     [], Pod::Installer::Analyzer::SpecsState.new, [], [],
                                                                     Installer::Analyzer::PodfileDependencyCache.from_podfile(@installer.podfile))
          @consumer = stub(:header_dir => 'myDir')
          @spec = stub(:name => 'Spec', :test_specification? => false, :library_specification? => true, :non_library_specification? => false,
                       :app_specification? => false, :consumer => @consumer)
          @spec.stubs(:root => @spec)
          @spec.stubs(:spec_type).returns(:library)
          @spec.stubs(:module_name => 'Spec')
          @pod_targets = [PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [@spec],
                                        [fixture_target_definition], nil)]
          @installer.stubs(:analysis_result).returns(@analysis_result)
          @installer.stubs(:pod_targets).returns(@pod_targets)
          @installer.stubs(:aggregate_targets).returns([])
        end

        it 'cleans the header stores' do
          FileUtils.mkdir_p(config.sandbox.target_support_files_root)
          @installer.pod_targets.each do |pods_target|
            pods_target.build_headers.expects(:implode_path!)
            config.sandbox.public_headers.expects(:implode_path!).with(pods_target.headers_sandbox)
          end
          @installer.send(:clean_sandbox, @installer.pod_targets)
        end

        it 'deletes the sources of the removed Pods' do
          FileUtils.mkdir_p(config.sandbox.target_support_files_root)
          @analysis_result.sandbox_state.add_name('Deleted-Pod', :deleted)
          config.sandbox.expects(:clean_pod).with('Deleted-Pod')
          @installer.send(:clean_sandbox, @installer.pod_targets)
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
          pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [spec], [fixture_target_definition],
                                     nil)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.instance_variable_set(:@installed_specs, [])
          Installer::PodSourceInstaller.any_instance.expects(:install!)
          @installer.send(:install_source_of_pod, 'BananaLib')
        end

        it 'maintains the list of the installed specs' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [spec], [fixture_target_definition],
                                     nil)
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
          spec.version = Version.new('2.0')
          manifest = Lockfile.new('SPEC REPOS' => { 'source1' => ['RestKit'] })
          manifest.stubs(:version).with('RestKit').returns(Version.new('1.0'))
          analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {},
                                                                    { Source.new('source1') => [spec] }, [spec],
                                                                    Pod::Installer::Analyzer::SpecsState.new, [], [], nil)
          @installer.stubs(:analysis_result).returns(analysis_result)
          @installer.sandbox.stubs(:manifest).returns(manifest)
          @installer.stubs(:root_specs).returns([spec])
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.changed << 'RestKit'
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
          UI.output.should.not.include 'source changed'
          UI.output.should.include 'was 1.0'
        end

        it 'does not print the spec repo of a pod if the source is the same but with different case' do
          spec = Spec.new
          spec.name = 'RestKit'
          spec.version = Version.new('1.0')
          manifest = Lockfile.new('SPEC REPOS' => { 'source1' => ['RestKit'] })
          manifest.stubs(:version).with('RestKit').returns(Version.new('1.0'))
          analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {},
                                                                    { Source.new('Source1') => [spec] }, [spec],
                                                                    Pod::Installer::Analyzer::SpecsState.new, [], [], nil)
          @installer.stubs(:analysis_result).returns(analysis_result)
          @installer.sandbox.stubs(:manifest).returns(manifest)
          @installer.stubs(:root_specs).returns([spec])
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.changed << 'RestKit'
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
          UI.output.should.not.include 'was 1.0'
          UI.output.should.not.include 'source changed'
        end

        it 'does not print the spec repo of a pod if the source is trunk when updating the spec' do
          spec = Spec.new
          spec.name = 'RestKit'
          spec.version = Version.new('2.0')
          manifest = Lockfile.new('SPEC REPOS' => { 'trunk' => ['RestKit'] })
          manifest.stubs(:version).with('RestKit').returns(Version.new('1.0'))
          analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {},
                                                                    { TrunkSource.new(Pod::TrunkSource::TRUNK_REPO_NAME) => [spec] }, [spec],
                                                                    Pod::Installer::Analyzer::SpecsState.new, [], [], nil)
          @installer.stubs(:analysis_result).returns(analysis_result)
          @installer.sandbox.stubs(:manifest).returns(manifest)
          @installer.stubs(:root_specs).returns([spec])
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.changed << 'RestKit'
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
          UI.output.should.not.include 'source changed'
          UI.output.should.include 'was 1.0'
        end

        it 'prints the spec repo of a pod while updating the spec with a new source' do
          spec = Spec.new
          spec.name = 'RestKit'
          spec.version = Version.new('1.0')
          manifest = Lockfile.new('SPEC REPOS' => { 'source1' => ['RestKit'] })
          manifest.stubs(:version).with('RestKit').returns(Version.new('1.0'))
          analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {},
                                                                    { Source.new('source2') => [spec] }, [spec],
                                                                    Pod::Installer::Analyzer::SpecsState.new, [], [], nil)
          @installer.stubs(:analysis_result).returns(analysis_result)
          @installer.sandbox.stubs(:manifest).returns(manifest)
          @installer.stubs(:root_specs).returns([spec])
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.changed << 'RestKit'
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
          UI.output.should.not.include 'was 1.0'
          UI.output.should.include 'source changed to `source2` from `source1`'
        end

        it 'prints the version and spec repo of a pod while updating the spec' do
          spec = Spec.new
          spec.name = 'RestKit'
          spec.version = Version.new('3.0')
          manifest = Lockfile.new('SPEC REPOS' => { 'source1' => ['RestKit'] })
          manifest.stubs(:version).with('RestKit').returns(Version.new('2.0'))
          analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {},
                                                                    { Source.new('source2') => [spec] }, [spec],
                                                                    Pod::Installer::Analyzer::SpecsState.new, [], [], nil)
          @installer.stubs(:analysis_result).returns(analysis_result)
          @installer.sandbox.stubs(:manifest).returns(manifest)
          @installer.stubs(:root_specs).returns([spec])
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.changed << 'RestKit'
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.expects(:install_source_of_pod).with('RestKit')
          @installer.send(:install_pod_sources)
          UI.output.should.include 'was 2.0 and source changed to `source2` from `source1`'
        end

        describe '#specs_for_pod' do
          it 'includes the specs by target name grouped by platform' do
            spec = fixture_spec('matryoshka/matryoshka.podspec')
            subspec = spec.subspec_by_name('matryoshka/Foo')
            targets = [
              ['matryoshka', Platform.ios, spec],
              ['matryoshka', Platform.osx, spec],
              ['matryoshka/Foo', Platform.ios, subspec],
            ]
            @pod_targets = targets.map do |(name, platform, target_spec)|
              target_definition = fixture_target_definition(name, platform)
              PodTarget.new(config.sandbox, BuildType.static_library, {}, [], platform, [target_spec], [target_definition], nil)
            end
            @installer.stubs(:pod_targets).returns(@pod_targets)
            @installer.send(:specs_for_pod, 'matryoshka').should == {
              Platform.ios => [spec, subspec],
              Platform.osx => [spec],
            }
          end
        end

        it 'creates a pod installer' do
          spec = fixture_spec('matryoshka/matryoshka.podspec')
          subspec = spec.subspec_by_name('matryoshka/Foo')
          targets = [
            ['matryoshka', Platform.ios, spec],
            ['matryoshka', Platform.osx, spec],
            ['matryoshka/Foo', Platform.ios, subspec],
          ]
          @pod_targets = targets.map do |(name, platform, target_spec)|
            target_definition = fixture_target_definition(name, platform)
            PodTarget.new(config.sandbox, BuildType.static_library, {}, [], platform, [target_spec], [target_definition], nil)
          end
          @installer.stubs(:pod_targets).returns(@pod_targets)
          pod_installer = @installer.send(:create_pod_installer, 'matryoshka')
          pod_installer.specs_by_platform.should == {
            Platform.ios => [spec, subspec],
            Platform.osx => [spec],
          }
          pod_installer.sandbox.should == @installer.sandbox
          pod_installer.can_cache.should.be.true?
        end

        it 'raises when it attempts to install pod source with no target supporting it' do
          spec = fixture_spec('banana-lib/BananaLib.podspec')
          pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [spec], [fixture_target_definition],
                                     nil)
          pod_target.stubs(:platform).returns(:ios)
          @installer.stubs(:pod_targets).returns([pod_target])
          should.raise StandardError do
            @installer.send(:create_pod_installer, 'RandomPod')
          end.message.should.include 'Could not install \'RandomPod\' pod. There is either no platform to build for, or no target to build.'
        end

        it 'prints a warning for installed pods that included script phases' do
          spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          spec.test_specs.first.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }
          pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [spec, *spec.test_specs],
                                     [fixture_target_definition], nil)
          pod_target.stubs(:platform).returns(:ios)
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.added << 'CoconutLib'
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.stubs(:root_specs).returns([spec])
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.send(:warn_for_installed_script_phases)
          UI.warnings.should.include 'CoconutLib has added 1 script phase. Please inspect before executing a build. ' \
            'See `https://guides.cocoapods.org/syntax/podspec.html#script_phases` for more information.'
        end

        it 'does not print a warning for already installed pods that include script phases' do
          spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          spec.test_specs.first.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }
          pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [spec, *spec.test_specs],
                                     [fixture_target_definition], nil)
          pod_target.stubs(:platform).returns(:ios)
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.unchanged << 'CoconutLib'
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.stubs(:root_specs).returns([spec])
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.send(:warn_for_installed_script_phases)
          UI.warnings.should.be.empty
        end

        it 'does not print a warning for a local pod that include script phases' do
          spec = fixture_spec('coconut-lib/CoconutLib.podspec')
          spec.test_specs.first.script_phase = { :name => 'Hello World', :script => 'echo "Hello World"' }
          pod_target = PodTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, [spec, *spec.test_specs],
                                     [fixture_target_definition], nil)
          pod_target.stubs(:platform).returns(:ios)
          config.sandbox.stubs(:local?).with('CoconutLib').returns(true)
          sandbox_state = Installer::Analyzer::SpecsState.new
          sandbox_state.changed << 'CoconutLib'
          @installer.stubs(:pod_targets).returns([pod_target])
          @installer.stubs(:root_specs).returns([spec])
          @installer.stubs(:sandbox_state).returns(sandbox_state)
          @installer.send(:warn_for_installed_script_phases)
          UI.warnings.should.be.empty
        end

        #--------------------------------------#

        describe '#clean' do
          it 'it cleans only if the config instructs to do it' do
            @installer.stubs(:installation_options).returns(Pod::Installer::InstallationOptions.new(:clean => false))
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
          podfile_dependency_cache = Installer::Analyzer::PodfileDependencyCache.from_podfile(@installer.podfile)
          @analysis_result = Installer::Analyzer::AnalysisResult.new(Pod::Installer::Analyzer::SpecsState.new, {}, {},
                                                                     [fixture_spec('banana-lib/BananaLib.podspec')],
                                                                     Pod::Installer::Analyzer::SpecsState.new, [], [],
                                                                     podfile_dependency_cache)
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
        target = AggregateTarget.new(config.sandbox, BuildType.static_library, {}, [], Platform.ios, fixture_target_definition,
                                     config.sandbox.root.dirname, nil, nil, {})
        @installer.stubs(:aggregate_targets).returns([target])
        Installer::UserProjectIntegrator.any_instance.expects(:integrate!)
        @installer.send(:integrate_user_project)
      end
    end

    describe 'Plugins Hooks' do
      before do
        @installer.send(:analyze)
        @specs = @installer.pod_targets.map(&:specs).flatten
        @spec = @specs.find { |spec| spec && spec.name == 'DfPodTest' }
        @installer.stubs(:installed_specs).returns(@specs)
      end

      describe 'DEFAULT_PLUGINS' do
        before do
          @default_plugins = @installer.send(:plugins)
        end

        it 'is empty' do
          @default_plugins.should == {}
        end
      end

      it 'runs plugins pre install hook' do
        context = stub
        Installer::PreInstallHooksContext.expects(:generate).returns(context)
        HooksManager.expects(:run).with(:pre_install, context, Installer::DEFAULT_PLUGINS)
        @installer.send(:run_plugins_pre_install_hooks)
      end

      it 'runs plugins pre integrate hook' do
        context = stub
        Installer::PreIntegrateHooksContext.expects(:generate).returns(context)
        HooksManager.expects(:run).with(:pre_integrate, context, Installer::DEFAULT_PLUGINS)
        @installer.expects(:any_plugin_pre_integrate_hooks?).returns(true)
        @installer.send(:run_plugins_pre_integrate_hooks)
      end

      it 'runs plugins post install hook' do
        context = stub
        Installer::PostInstallHooksContext.expects(:generate).returns(context)
        HooksManager.expects(:run).with(:post_install, context, Installer::DEFAULT_PLUGINS)
        @installer.expects(:any_plugin_post_install_hooks?).returns(true)
        @installer.send(:run_plugins_post_install_hooks)
      end

      it 'runs plugins post integrate hook' do
        context = stub
        Installer::PostIntegrateHooksContext.expects(:generate).returns(context)
        HooksManager.expects(:run).with(:post_integrate, context, Installer::DEFAULT_PLUGINS)
        @installer.expects(:any_plugin_post_integrate_hooks?).returns(true)
        @installer.send(:run_plugins_post_integrate_hooks)
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
        @installer.expects(:any_plugin_post_install_hooks?).returns(true)
        @installer.send(:run_plugins_post_install_hooks)
      end

      it 'does not unlock sources with no hooks' do
        @installer.expects(:any_plugin_post_install_hooks?).returns(false)

        @installer.expects(:unlock_pod_sources).never
        HooksManager.expects(:run).never
        @installer.expects(:lock_pod_sources).once
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
          install! 'cocoapods', :integrate_targets => false
          platform :ios
        end
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

    #-------------------------------------------------------------------------#

    describe '.targets_from_sandbox' do
      it 'raises when there is no lockfile' do
        sandbox = config.sandbox
        podfile = generate_podfile
        lockfile = nil

        should.raise Informative do
          Installer.targets_from_sandbox(sandbox, podfile, lockfile)
        end.message.should.include 'You must run `pod install` to be able to generate target information'
      end

      it 'raises when the podfile has changed' do
        sandbox = config.sandbox
        podfile = generate_podfile(['AFNetworking'])
        lockfile = generate_lockfile

        should.raise Informative do
          Installer.targets_from_sandbox(sandbox, podfile, lockfile)
        end.message.should.include 'The Podfile has changed, you must run `pod install`'
      end

      it 'raises when the sandbox has changed' do
        sandbox = config.sandbox
        podfile = generate_podfile
        lockfile = generate_lockfile
        lockfile.internal_data['DEPENDENCIES'] = podfile.dependencies.map(&:to_s)

        should.raise Informative do
          Installer.targets_from_sandbox(sandbox, podfile, lockfile)
        end.message.should.include 'The `Pods` directory is out-of-date, you must run `pod install`'
      end

      it 'returns the aggregate targets without performing installation with trunk pod' do
        podfile = generate_podfile
        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.install!

        ::SpecHelper.reset_config_instance

        aggregate_targets = Installer.targets_from_sandbox(config.sandbox, podfile, config.lockfile)

        aggregate_targets.map(&:target_definition).should == [
          podfile.target_definitions['SampleProject'], podfile.target_definitions['SampleProjectTests']
        ]

        aggregate_targets.last.pod_targets.should == []
        sample_project_target = aggregate_targets.first
        sample_project_target.pod_targets.map(&:label).should == %w(DfPodTest FMDB)

        dfpodtest = sample_project_target.pod_targets.first

        dfpodtest.sandbox.should == config.sandbox
        dfpodtest.file_accessors.flat_map(&:root).should == [config.sandbox.pod_dir('DfPodTest')]
        dfpodtest.archs.should == []
      end

      it 'returns the aggregate targets without performing installation with local pods' do
        podfile = generate_local_podfile
        lockfile = generate_lockfile

        @installer = Installer.new(config.sandbox, podfile, lockfile)
        @installer.expects(:integrate_user_project)
        @installer.install!

        ::SpecHelper.reset_config_instance

        aggregate_targets = Installer.targets_from_sandbox(config.sandbox, podfile, config.lockfile)

        aggregate_targets.map(&:target_definition).should == [
          podfile.target_definitions['SampleProject'], podfile.target_definitions['SampleProjectTests']
        ]

        aggregate_targets.last.pod_targets.should == []
        sample_project_target = aggregate_targets.first
        sample_project_target.pod_targets.map(&:label).should == %w(Reachability)

        dfpodtest = sample_project_target.pod_targets.first

        dfpodtest.sandbox.should == config.sandbox
        dfpodtest.file_accessors.flat_map(&:root).should == [config.sandbox.pod_dir('Reachability')]
        dfpodtest.archs.should == []
      end
    end
  end
end
