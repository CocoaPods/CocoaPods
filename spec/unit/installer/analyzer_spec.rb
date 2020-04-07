require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::Analyzer do # rubocop:disable Metrics/BlockLength
    describe 'Analysis' do # rubocop:disable Metrics/BlockLength
      before do
        repos = [Source.new(fixture('spec-repos/test_repo')), TrunkSource.new(fixture('spec-repos/trunk'))]
        aggregate = Pod::Source::Aggregate.new(repos)
        @sources_manager = Source::Manager.new(config.repos_dir)
        @sources_manager.stubs(:aggregate).returns(aggregate)
        aggregate.sources.first.stubs(:url).returns(SpecHelper.test_repo_url)

        @podfile = Pod::Podfile.new do
          platform :ios, '6.0'
          project 'SampleProject/SampleProject'

          target 'SampleProject' do
            pod 'JSONKit',                     '1.5pre'
            pod 'AFNetworking',                '1.0.1'
            pod 'SVPullToRefresh',             '0.4'
            pod 'libextobjc/EXTKeyPathCoding', '0.2.3'

            target 'TestRunner' do
              inherit! :search_paths

              pod 'libextobjc/EXTKeyPathCoding', '0.2.3'
              pod 'libextobjc/EXTSynthesize',    '0.2.3'
            end
          end
        end

        hash = {}
        hash['PODS'] = ['JSONKit (1.5pre)', 'NUI (0.2.0)', 'SVPullToRefresh (0.4)']
        hash['DEPENDENCIES'] = %w(JSONKit NUI SVPullToRefresh)
        hash['SPEC CHECKSUMS'] = {}
        hash['COCOAPODS'] = Pod::VERSION
        @lockfile = Pod::Lockfile.new(hash)

        SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, @lockfile, [], true, false, @sources_manager)
      end

      it 'returns whether an installation should be performed' do
        @analyzer.analyze.needs_install?.should.be.true
      end

      it 'returns whether the Podfile has changes' do
        @analyzer.analyze(false).podfile_needs_install?.should.be.true
      end

      it 'returns whether the sandbox is not in sync with the lockfile' do
        @analyzer.analyze(false).sandbox_needs_install?.should.be.true
      end

      #--------------------------------------#

      it 'computes the state of the Podfile respect to the Lockfile' do
        state = @analyzer.analyze.podfile_state
        state.added.should == Set.new(%w(AFNetworking libextobjc libextobjc))
        state.changed.should == Set.new(%w())
        state.unchanged.should == Set.new(%w(JSONKit SVPullToRefresh))
        state.deleted.should == Set.new(%w(NUI))
      end

      #--------------------------------------#

      it 'does not update unused sources' do
        @analyzer.stubs(:sources).returns(@sources_manager.master)
        @sources_manager.expects(:update).once.with('trunk', true)
        @analyzer.update_repositories
      end

      it 'does not update sources if there are no dependencies' do
        podfile = Podfile.new do
          source Pod::TrunkSource::TRUNK_REPO_URL
          # No dependencies specified
        end
        config.verbose = true

        config.sources_manager.expects(:update).never
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        analyzer.update_repositories
      end

      it 'does not update non-updateable repositories' do
        tmp_directory = Pathname(Dir.tmpdir) + 'CocoaPods'
        FileUtils.mkdir_p(tmp_directory)
        FileUtils.cp_r(ROOT + 'spec/fixtures/spec-repos/test_repo/', tmp_directory)
        non_git_repo = tmp_directory + 'test_repo'
        FileUtils.rm(non_git_repo + '.git')

        podfile = Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          pod 'BananaLib', '1.0'
        end
        config.verbose = true

        source = Source.new(non_git_repo)

        config.sources_manager.expects(:update).never
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        analyzer.stubs(:sources).returns([source])
        analyzer.update_repositories

        UI.output.should.match /Skipping `#{source.name}` update because the repository is not an updateable repository./

        FileUtils.rm_rf(non_git_repo)
      end

      it 'updates sources specified with dependencies' do
        repo_url = 'https://url/to/specs.git'
        podfile = Podfile.new do
          source 'repo_1'
          pod 'BananaLib', '1.0', :source => repo_url
          pod 'JSONKit', :source => repo_url
        end

        # Note that we are explicitly ignoring 'repo_1' since it isn't used.
        source = mock('source', :name => 'repo_2', :updateable? => true)
        sources_manager = Source::Manager.new(config.repos_dir)
        sources_manager.expects(:find_or_create_source_with_url).with(repo_url).returns(source)
        sources_manager.expects(:update).once.with('repo_2', true)

        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil, [],
                                                true, false, sources_manager)
        analyzer.update_repositories
      end

      it 'includes trunk if not all dependencies have a source' do
        repo_url = 'https://url/to/specs.git'
        podfile = Podfile.new do
          pod 'BananaLib', '1.0'
          pod 'JSONKit', :source => repo_url
        end

        source = mock('source')
        mock_master = mock('source')
        sources_manager = Source::Manager.new(config.repos_dir)
        sources_manager.stubs(:master).returns([mock_master])
        sources_manager.expects(:find_or_create_source_with_url).with(repo_url).returns(source)
        sources_manager.expects(:find_or_create_source_with_url).with(Pod::TrunkSource::TRUNK_REPO_URL).returns(mock_master)

        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil, [], true, false, sources_manager)
        analyzer.sources.should == [mock_master, source]
      end

      it 'registers plugin sources with the sources manager' do
        podfile = Podfile.new do
          pod 'BananaLib', '1.0'
          pod 'JSONKit'
          pod 'PrivatePod'
        end

        spec = Pod::Specification.new do |s|
          s.name = 'PrivatePod'
          s.version = '1.0.0'
          s.source_files = '**/*.swift'
        end

        repo_dir = SpecHelper.temporary_directory + 'repos'
        repo_dir.mkpath

        source_repo_dir = repo_dir + 'my-specs'
        source_repo_dir.mkpath

        plugin_source = Pod::Source.new(source_repo_dir)
        plugin_source.stubs(:all_specs).returns([spec])
        plugin_source.stubs(:url).returns('protocol://special-source.org/my-specs')
        plugin_source.stubs(:updateable?).returns(false)

        sources_manager = Source::Manager.new(repo_dir)
        sources_manager.stubs(:cdn_url?).returns(false)

        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil, [plugin_source], true, false, sources_manager)
        analyzer.send(:sources)

        dependency = Pod::Dependency.new('PrivatePod', '1.0.0', :source => 'protocol://special-source.org/my-specs')

        result = sources_manager.aggregate_for_dependency(dependency)
        result.sources.map(&:name).should == ['my-specs']

        FileUtils.rm_rf(repo_dir.dirname)
      end

      #--------------------------------------#

      it 'generates the model to represent the target definitions' do
        result = @analyzer.analyze
        target, test_target = result.targets

        test_target.pod_targets.map(&:name).sort.should == %w(
          libextobjc-EXTKeyPathCoding-EXTSynthesize
        ).sort

        target.pod_targets.map(&:name).sort.should == %w(
          JSONKit
          AFNetworking
          libextobjc-EXTKeyPathCoding
          SVPullToRefresh
        ).sort
        target.support_files_dir.should == config.sandbox.target_support_files_dir('Pods-SampleProject')

        target.pod_targets.map(&:archs).uniq.should == [[]]

        target.user_project_path.to_s.should.include 'SampleProject/SampleProject'
        target.client_root.to_s.should.include 'SampleProject'
        target.user_target_uuids.should == ['A346496C14F9BE9A0080D870']
        user_proj = Xcodeproj::Project.open(target.user_project_path)
        user_proj.objects_by_uuid[target.user_target_uuids.first].name.should == 'SampleProject'
        target.user_build_configurations.should == {
          'Debug'     => :debug,
          'Release'   => :release,
          'Test'      => :release,
          'App Store' => :release,
        }
        target.platform.to_s.should == 'iOS 6.0'
      end

      describe 'platform architectures' do
        it 'correctly determines when a platform requires 64-bit architectures' do
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:ios, '11.0'), nil).should.be.true
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:ios, '12.0'), nil).should.be.true
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:ios, '10.0'), nil).should.be.false
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:osx), nil).should.be.true
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:tvos), nil).should.be.false
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:watchos), nil).should.be.false
        end

        it 'does not specify 64-bit architectures on Xcode 10+' do
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:ios, '11.0'), 49).should.be.true
          Installer::Analyzer.send(:requires_64_bit_archs?, Platform.new(:ios, '11.0'), 50).should.be.false
        end

        it 'forces 64-bit architectures when required' do
          @podfile = Pod::Podfile.new do
            project 'SampleProject/SampleProject'
            platform :ios, '11.0'
            use_frameworks!
            target 'TestRunner' do
              pod 'AFNetworking'
              pod 'JSONKit'
            end
          end
          @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
          result = @analyzer.analyze

          result.pod_targets.map(&:archs).uniq.should == [['$(ARCHS_STANDARD_64_BIT)']]
        end

        it 'forces 64-bit architectures only for the targets that require it' do
          @podfile = Pod::Podfile.new do
            project 'SampleProject/SampleProject'

            use_frameworks!
            target 'SampleProject' do
              platform :ios, '10.0'
              pod 'AFNetworking'
              target 'TestRunner' do
                platform :ios, '11.0'
                pod 'JSONKit'
                pod 'SOCKit'
              end
            end
          end
          Xcodeproj::Project.any_instance.stubs(:object_version).returns('49')
          @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
          result = @analyzer.analyze

          non_64_bit_target = result.pod_targets.shift

          non_64_bit_target.send(:archs).should == []
          result.pod_targets.map(&:archs).uniq.should == [['$(ARCHS_STANDARD_64_BIT)']]
        end

        it 'does not force 64-bit architectures on Xcode 10+' do
          @podfile = Pod::Podfile.new do
            project 'SampleProject/SampleProject'
            platform :ios, '11.0'
            use_frameworks!
            target 'TestRunner' do
              pod 'AFNetworking'
              pod 'JSONKit'
            end
          end
          Xcodeproj::Project.any_instance.stubs(:object_version).returns('50')
          @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
          result = @analyzer.analyze

          result.pod_targets.map(&:archs).uniq.should == [[]]
        end

        it 'does not specify archs value unless required' do
          @podfile = Pod::Podfile.new do
            project 'SampleProject/SampleProject'
            platform :ios, '10.0'
            use_frameworks!
            target 'TestRunner' do
              pod 'AFNetworking'
              pod 'JSONKit'
            end
          end
          @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
          result = @analyzer.analyze

          result.pod_targets.map(&:archs).uniq.should == [[]]
        end
      end

      describe 'abstract targets' do
        it 'resolves' do
          @podfile = Pod::Podfile.new do
            project 'SampleProject/SampleProject'
            use_frameworks!
            abstract_target 'Alpha' do
              pod 'libextobjc'
              target 'SampleProject' do
                pod 'libextobjc/RuntimeExtensions'
              end

              target 'TestRunner' do
              end
            end
          end
          @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
          result = @analyzer.analyze
          sample_project_target, test_runner_target = result.targets.sort_by(&:name)

          sample_project_target.pod_targets.map(&:name).should == %w(libextobjc-iOS5.0)
          test_runner_target.pod_targets.map(&:name).should == %w(libextobjc-iOS5.1)

          sample_project_target.user_targets.map(&:name).should == %w(SampleProject)
          test_runner_target.user_targets.map(&:name).should == %w(TestRunner)
        end
      end

      describe 'dependent pod targets' do
        it 'raises when a pod depends on a non-library spec' do
          @podfile = Pod::Podfile.new do
            platform :ios, '10.0'
            project 'SampleProject/SampleProject'

            # The order of target definitions is important for this test.
            target 'SampleProject' do
              pod 'a', :testspecs => %w(Tests), :appspecs => %w(App), :git => '.'
              pod 'b', :testspecs => %w(Tests), :appspecs => %w(App), :git => '.'
            end
          end

          pod_a = Pod::Spec.new do |s|
            s.name = 'a'
            s.version = '1.0'
            s.test_spec 'Tests'
            s.app_spec 'App'
          end
          pod_b = Pod::Spec.new do |s|
            s.name = 'b'
            s.version = '1.0'
            s.dependency 'a/Tests'
            s.test_spec 'Tests'
            s.app_spec 'App'
          end

          analyze = -> do
            sandbox = Pod::Sandbox.new(config.sandbox.root)
            @analyzer = Pod::Installer::Analyzer.new(sandbox, @podfile, nil)
            @analyzer.expects(:fetch_external_source).twice
            @analyzer.sandbox.expects(:specification).with('a').returns(pod_a)
            @analyzer.sandbox.expects(:specification).with('b').returns(pod_b)
            @analyzer.analyze
          end

          analyze.should.raise(Informative).
            message.should.include '`b (1.0)` depends upon `a/Tests (1.0)`, which is a `test` spec.'

          pod_b = Pod::Spec.new do |s|
            s.name = 'b'
            s.version = '1.0'
            s.test_spec 'Tests' do |ts|
              ts.dependency 'b/App'
            end
            s.app_spec 'App'
          end
          analyze.should.raise(Informative).
            message.should.include '`b/Tests (1.0)` depends upon `b/App (1.0)`, which is a `app` spec'
        end

        describe 'with deduplicate targets as true' do
          before { Installer::InstallationOptions.any_instance.stubs(:deduplicate_targets? => true) }

          it 'picks transitive dependencies up' do
            @podfile = Pod::Podfile.new do
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'
              pod 'RestKit', '~> 0.23.0'
              target 'TestRunner' do
                pod 'RestKit/Testing', '~> 0.23.0'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
            result = @analyzer.analyze
            result.targets.count.should == 1
            target = result.targets.first
            restkit_target = target.pod_targets.find { |pt| pt.pod_name == 'RestKit' }
            restkit_target.dependent_targets.map(&:pod_name).sort.should == %w(
              AFNetworking
              ISO8601DateFormatterValueTransformer
              RKValueTransformers
              SOCKit
              TransitionKit
            )
            restkit_target.recursive_dependent_targets.map(&:pod_name).sort.should == %w(
              AFNetworking
              ISO8601DateFormatterValueTransformer
              RKValueTransformers
              SOCKit
              TransitionKit
            )
            restkit_target.dependent_targets.all?(&:scoped).should.be.true
          end

          it 'does not mark transitive dependencies as dependent targets' do
            @podfile = Pod::Podfile.new do
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'
              target 'SampleProject'
              pod 'Firebase', '3.9.0'
              pod 'ARAnalytics', '4.0.0', :subspecs => %w(Firebase)
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
            result = @analyzer.analyze
            result.targets.count.should == 1
            target = result.targets.first

            firebase_target = target.pod_targets.find { |pt| pt.pod_name == 'Firebase' }
            firebase_target.dependent_targets.map(&:pod_name).sort.should == %w(
              FirebaseAnalytics FirebaseCore
            )
            firebase_target.recursive_dependent_targets.map(&:pod_name).sort.should == %w(
              FirebaseAnalytics FirebaseCore FirebaseInstanceID GoogleInterchangeUtilities GoogleSymbolUtilities GoogleToolboxForMac
            )
            firebase_target.dependent_targets.all?(&:scoped).should.be.true

            aranalytics_target = target.pod_targets.find { |pt| pt.pod_name == 'ARAnalytics' }
            aranalytics_target.dependent_targets.map(&:pod_name).sort.should == %w(
              Firebase
            )
            aranalytics_target.recursive_dependent_targets.map(&:pod_name).sort.should == %w(
              Firebase FirebaseAnalytics FirebaseCore FirebaseInstanceID GoogleInterchangeUtilities GoogleSymbolUtilities GoogleToolboxForMac
            )
            aranalytics_target.dependent_targets.all?(&:scoped).should.be.true
          end

          it 'correctly computes recursive dependent targets' do
            @podfile = Pod::Podfile.new do
              platform :ios, '10.0'
              project 'SampleProject/SampleProject'

              # The order of target definitions is important for this test.
              target 'SampleProject' do
                pod 'a', :testspecs => %w(Tests)
                pod 'b', :testspecs => %w(Tests)
                pod 'c', :testspecs => %w(Tests)
                pod 'd', :testspecs => %w(Tests)
                pod 'app_host', :testspecs => %w(Tests)
                pod 'base'
              end
            end

            source = MockSource.new 'Source' do
              pod 'base' do
                test_spec do |ts|
                  ts.dependency 'base_testing'
                end
              end

              pod 'a' do |s|
                s.dependency 'b'
                s.dependency 'base'
                test_spec do |ts|
                  ts.dependency 'a_testing'
                end
              end

              pod 'b' do |s|
                s.dependency 'c'
                test_spec do |ts|
                end
              end

              pod 'c' do |s|
                s.dependency 'e'
                test_spec do |ts|
                  ts.dependency 'a_testing'

                  ts.requires_app_host = true
                  ts.app_host_name = 'app_host/App'
                  ts.dependency 'app_host/App'
                end
              end

              pod 'd' do |s|
                s.dependency 'a'
                test_spec do |ts|
                  ts.dependency 'b'
                end
              end

              pod 'e' do |s|
                s.dependency 'base'
                test_spec do |ts|
                end
              end

              pod 'a_testing' do |s|
                s.dependency 'a'
                s.dependency 'base_testing'
                test_spec do |ts|
                  ts.dependency 'base_testing'
                end
              end

              pod 'base_testing' do |s|
                s.dependency 'base'
                test_spec do |ts|
                end
              end

              pod 'app_host' do |s|
                s.dependency 'base'
                app_spec do |as|
                  as.dependency 'd'
                end
                test_spec do |ts|
                  ts.requires_app_host = true
                  ts.app_host_name = 'app_host/App'
                  ts.dependency 'app_host/App'
                end
              end
            end
            config.verbose = true

            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
            @analyzer.stubs(:sources).returns([source])
            result = @analyzer.analyze

            pod_target = result.pod_targets.find { |pt| pt.name == 'a' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == %w(b base)
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(b base c e)
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['a/Tests', ['a_testing']]]
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(a a_testing b base base_testing c e)
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'a_testing' }
            pod_target.dependent_targets.map(&:name).sort.should == %w(a base_testing)
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(a b base base_testing c e)
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'b' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == ['c']
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(base c e)
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['b/Tests', []]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'base' }
            pod_target.dependent_targets.map(&:name).sort.should == []
            pod_target.recursive_dependent_targets.map(&:name).sort.should == []
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'c' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == ['e']
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(base e)
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['c/Tests', ['a_testing']]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(a a_testing b base base_testing c e)
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.map { |k, v| [k.name, v.map(&:name)] }.should == [['c/Tests', ['app_host/App', 'app_host']]]

            pod_target = result.pod_targets.find { |pt| pt.name == 'd' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == ['a']
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(a b base c e)
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['d/Tests', ['b']]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(b base c e)
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'e' }
            pod_target.dependent_targets.map(&:name).sort.should == ['base']
            pod_target.recursive_dependent_targets.map(&:name).sort.should == ['base']
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'app_host' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            app_spec = pod_target.app_specs.find { |as| as.name == "#{pod_target.pod_name}/App" }
            pod_target.dependent_targets.map(&:name).sort.should == ['base']
            pod_target.recursive_dependent_targets.map(&:name).sort.should == ['base']
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['app_host/Tests', []]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['app_host/App', ['d']]]
            pod_target.recursive_app_dependent_targets(app_spec).map(&:name).sort.should == %w(a b base c d e)
            pod_target.test_app_hosts_by_spec.map { |k, v| [k.name, v.map(&:name)] }.should == [['app_host/Tests', ['app_host/App', 'app_host']]]
          end

          it 'correctly computes recursive dependent targets for scoped pod targets' do
            @podfile = Pod::Podfile.new do
              project 'SampleProject/SampleProject'

              pod 'a', :testspecs => %w(Tests)
              pod 'b', :testspecs => %w(Tests)
              pod 'c', :testspecs => %w(Tests)
              pod 'd', :testspecs => %w(Tests)
              pod 'app_host', :testspecs => %w(Tests)
              pod 'base'

              target 'SampleProject' do
                platform :ios, '10.0'
              end

              target 'CLITool' do
                platform :osx, '10.14'
              end
            end

            source = MockSource.new 'Source' do
              pod 'base' do
                test_spec do |ts|
                  ts.dependency 'base_testing'
                end
              end

              pod 'a' do |s|
                s.dependency 'b'
                s.dependency 'base'
                test_spec do |ts|
                  ts.dependency 'a_testing'
                end
              end

              pod 'b' do |s|
                s.dependency 'c'
                test_spec do |ts|
                end
              end

              pod 'c' do |s|
                s.dependency 'e'
                test_spec do |ts|
                  ts.dependency 'a_testing'

                  ts.requires_app_host = true
                  ts.app_host_name = 'app_host/App'
                  ts.dependency 'app_host/App'
                end
              end

              pod 'd' do |s|
                s.dependency 'a'
                test_spec do |ts|
                  ts.dependency 'b'
                end
              end

              pod 'e' do |s|
                s.dependency 'base'
                test_spec do |ts|
                end
              end

              pod 'a_testing' do |s|
                s.dependency 'a'
                s.dependency 'base_testing'
                test_spec do |ts|
                  ts.dependency 'base_testing'
                end
              end

              pod 'base_testing' do |s|
                s.dependency 'base'
                test_spec do |ts|
                end
              end

              pod 'app_host' do |s|
                s.dependency 'base'
                app_spec do |as|
                  as.dependency 'd'
                end
                test_spec do |ts|
                  ts.requires_app_host = true
                  ts.app_host_name = 'app_host/App'
                  ts.dependency 'app_host/App'
                end
              end
            end

            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            @analyzer.stubs(:sources).returns([source])
            result = @analyzer.analyze

            %w(-macOS -iOS).each do |scope|
              pod_target = result.pod_targets.find { |pt| pt.name == 'a' + scope }
              test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
              pod_target.dependent_targets.map(&:name).sort.should == %w(b base).map { |n| n + scope }
              pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(b base c e).map { |n| n + scope }
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['a/Tests', ['a_testing'].map { |n| n + scope }]]
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(a a_testing b base base_testing c e).map { |n| n + scope }
              pod_target.test_app_hosts_by_spec.should == {}

              pod_target = result.pod_targets.find { |pt| pt.name == 'a_testing' + scope }
              pod_target.dependent_targets.map(&:name).sort.should == %w(a base_testing).map { |n| n + scope }
              pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(a b base base_testing c e).map { |n| n + scope }
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.test_app_hosts_by_spec.should == {}

              pod_target = result.pod_targets.find { |pt| pt.name == 'b' + scope }
              test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
              pod_target.dependent_targets.map(&:name).sort.should == ['c'].map { |n| n + scope }
              pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(base c e).map { |n| n + scope }
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['b/Tests', []]]
              pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == []
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.test_app_hosts_by_spec.should == {}

              pod_target = result.pod_targets.find { |pt| pt.name == 'base' + scope }
              pod_target.dependent_targets.map(&:name).sort.should == []
              pod_target.recursive_dependent_targets.map(&:name).sort.should == []
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.test_app_hosts_by_spec.should == {}

              pod_target = result.pod_targets.find { |pt| pt.name == 'c' + scope }
              test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
              pod_target.dependent_targets.map(&:name).sort.should == ['e'].map { |n| n + scope }
              pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(base e).map { |n| n + scope }
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['c/Tests', ['a_testing'].map { |n| n + scope }]]
              pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(a a_testing b base base_testing c e).map { |n| n + scope }
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.test_app_hosts_by_spec.map { |k, v| [k.name, v.map(&:name)] }.should == [['c/Tests', ['app_host/App', 'app_host' + scope]]]

              pod_target = result.pod_targets.find { |pt| pt.name == 'd' + scope }
              test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
              pod_target.dependent_targets.map(&:name).sort.should == ['a'].map { |n| n + scope }
              pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(a b base c e).map { |n| n + scope }
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['d/Tests', ['b'].map { |n| n + scope }]]
              pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(b base c e).map { |n| n + scope }
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.test_app_hosts_by_spec.should == {}

              pod_target = result.pod_targets.find { |pt| pt.name == 'e' + scope }
              pod_target.dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + scope }
              pod_target.recursive_dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + scope }
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
              pod_target.test_app_hosts_by_spec.should == {}

              pod_target = result.pod_targets.find { |pt| pt.name == 'app_host' + scope }
              test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
              app_spec = pod_target.app_specs.find { |as| as.name == "#{pod_target.pod_name}/App" }
              pod_target.dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + scope }
              pod_target.recursive_dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + scope }
              pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['app_host/Tests', []]]
              pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == []
              pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['app_host/App', ['d'].map { |n| n + scope }]]
              pod_target.recursive_app_dependent_targets(app_spec).map(&:name).sort.should == %w(a b base c d e).map { |n| n + scope }
              pod_target.test_app_hosts_by_spec.map { |k, v| [k.name, v.map(&:name)] }.should == [['app_host/Tests', ['app_host/App', 'app_host' + scope]]]
            end
          end

          it 'picks the right variants up when there are multiple' do
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'

              # The order of target definitions is important for this test.
              target 'TestRunner' do
                pod 'OrangeFramework'
                pod 'matryoshka/Foo'
              end

              target 'SampleProject' do
                pod 'OrangeFramework'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze

            result.targets.count.should == 2

            pod_target = result.targets[0].pod_targets.find { |pt| pt.pod_name == 'OrangeFramework' }
            pod_target.dependent_targets.count == 1
            pod_target.dependent_targets.first.specs.map(&:name).should == %w(
              matryoshka
              matryoshka/Outer
              matryoshka/Outer/Inner
            )
          end

          it 'does not create multiple variants across different targets that require different set of testspecs' do
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'

              target 'TestRunner' do
                pod 'CoconutLib', :testspecs => ['Tests']
              end

              target 'SampleProject' do
                pod 'CoconutLib'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze

            result.targets.count.should == 2
            result.targets[0].pod_targets.count == 1
            result.targets[0].pod_targets[0].name.should == 'CoconutLib'
            result.targets[1].pod_targets.count == 1
            result.targets[1].pod_targets[0].name.should == 'CoconutLib'
            result.targets[0].pod_targets[0].should == result.targets[1].pod_targets[0]
          end
        end

        describe 'with deduplicate targets as false' do
          before { Installer::InstallationOptions.any_instance.stubs(:deduplicate_targets? => false) }

          it 'picks transitive dependencies up' do
            @podfile = Pod::Podfile.new do
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'
              pod 'RestKit', '~> 0.23.0'
              target 'TestRunner' do
                pod 'RestKit/Testing', '~> 0.23.0'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze
            result.targets.count.should == 1
            target = result.targets.first
            restkit_target = target.pod_targets.find { |pt| pt.pod_name == 'RestKit' }
            restkit_target.dependent_targets.map(&:pod_name).sort.should == %w(
              AFNetworking
              ISO8601DateFormatterValueTransformer
              RKValueTransformers
              SOCKit
              TransitionKit
            )
            restkit_target.recursive_dependent_targets.map(&:pod_name).sort.should == %w(
              AFNetworking
              ISO8601DateFormatterValueTransformer
              RKValueTransformers
              SOCKit
              TransitionKit
            )
            restkit_target.dependent_targets.all?(&:scoped).should.be.true
          end

          it 'does not mark transitive dependencies as dependent targets' do
            @podfile = Pod::Podfile.new do
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'
              target 'SampleProject'
              pod 'Firebase', '3.9.0'
              pod 'ARAnalytics', '4.0.0', :subspecs => %w(Firebase)
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze
            result.targets.count.should == 1
            target = result.targets.first

            firebase_target = target.pod_targets.find { |pt| pt.pod_name == 'Firebase' }
            firebase_target.dependent_targets.map(&:pod_name).sort.should == %w(
              FirebaseAnalytics FirebaseCore
            )
            firebase_target.recursive_dependent_targets.map(&:pod_name).sort.should == %w(
              FirebaseAnalytics FirebaseCore FirebaseInstanceID GoogleInterchangeUtilities GoogleSymbolUtilities GoogleToolboxForMac
            )
            firebase_target.dependent_targets.all?(&:scoped).should.be.true

            aranalytics_target = target.pod_targets.find { |pt| pt.pod_name == 'ARAnalytics' }
            aranalytics_target.dependent_targets.map(&:pod_name).sort.should == %w(
              Firebase
            )
            aranalytics_target.recursive_dependent_targets.map(&:pod_name).sort.should == %w(
              Firebase FirebaseAnalytics FirebaseCore FirebaseInstanceID GoogleInterchangeUtilities GoogleSymbolUtilities GoogleToolboxForMac
            )
            aranalytics_target.dependent_targets.all?(&:scoped).should.be.true
          end

          it 'correctly computes recursive dependent targets' do
            @podfile = Pod::Podfile.new do
              platform :ios, '10.0'
              project 'SampleProject/SampleProject'

              # The order of target definitions is important for this test.
              target 'SampleProject' do
                pod 'a', :testspecs => %w(Tests)
                pod 'b', :testspecs => %w(Tests)
                pod 'c', :testspecs => %w(Tests)
                pod 'd', :testspecs => %w(Tests)
                pod 'app_host', :testspecs => %w(Tests)
                pod 'base'
              end
            end

            source = MockSource.new 'Source' do
              pod 'base' do
                test_spec do |ts|
                  ts.dependency 'base_testing'
                end
              end

              pod 'a' do |s|
                s.dependency 'b'
                s.dependency 'base'
                test_spec do |ts|
                  ts.dependency 'a_testing'
                end
              end

              pod 'b' do |s|
                s.dependency 'c'
                test_spec do |ts|
                end
              end

              pod 'c' do |s|
                s.dependency 'e'
                test_spec do |ts|
                  ts.dependency 'a_testing'

                  ts.requires_app_host = true
                  ts.app_host_name = 'app_host/App'
                  ts.dependency 'app_host/App'
                end
              end

              pod 'd' do |s|
                s.dependency 'a'
                test_spec do |ts|
                  ts.dependency 'b'
                end
              end

              pod 'e' do |s|
                s.dependency 'base'
                test_spec do |ts|
                end
              end

              pod 'a_testing' do |s|
                s.dependency 'a'
                s.dependency 'base_testing'
                test_spec do |ts|
                  ts.dependency 'base_testing'
                end
              end

              pod 'base_testing' do |s|
                s.dependency 'base'
                test_spec do |ts|
                end
              end

              pod 'app_host' do |s|
                s.dependency 'base'
                app_spec do |as|
                  as.dependency 'd'
                end
                test_spec do |ts|
                  ts.requires_app_host = true
                  ts.app_host_name = 'app_host/App'
                  ts.dependency 'app_host/App'
                end
              end
            end

            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            @analyzer.stubs(:sources).returns([source])
            result = @analyzer.analyze

            pod_target = result.pod_targets.find { |pt| pt.name == 'a-Pods-SampleProject' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == %w(b base).map { |n| n + '-Pods-SampleProject' }
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(b base c e).map { |n| n + '-Pods-SampleProject' }
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['a/Tests', ['a_testing'].map { |n| n + '-Pods-SampleProject' }]]
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(a a_testing b base base_testing c e).map { |n| n + '-Pods-SampleProject' }
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'a_testing-Pods-SampleProject' }
            pod_target.dependent_targets.map(&:name).sort.should == %w(a base_testing).map { |n| n + '-Pods-SampleProject' }
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(a b base base_testing c e).map { |n| n + '-Pods-SampleProject' }
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'b-Pods-SampleProject' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == ['c'].map { |n| n + '-Pods-SampleProject' }
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(base c e).map { |n| n + '-Pods-SampleProject' }
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['b/Tests', []]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'base-Pods-SampleProject' }
            pod_target.dependent_targets.map(&:name).sort.should == []
            pod_target.recursive_dependent_targets.map(&:name).sort.should == []
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'c-Pods-SampleProject' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == ['e'].map { |n| n + '-Pods-SampleProject' }
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(base e).map { |n| n + '-Pods-SampleProject' }
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['c/Tests', ['a_testing'].map { |n| n + '-Pods-SampleProject' }]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(a a_testing b base base_testing c e).map { |n| n + '-Pods-SampleProject' }
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.map { |k, v| [k.name, v.map(&:name)] }.should == [['c/Tests', ['app_host/App', 'app_host-Pods-SampleProject']]]

            pod_target = result.pod_targets.find { |pt| pt.name == 'd-Pods-SampleProject' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            pod_target.dependent_targets.map(&:name).sort.should == ['a'].map { |n| n + '-Pods-SampleProject' }
            pod_target.recursive_dependent_targets.map(&:name).sort.should == %w(a b base c e).map { |n| n + '-Pods-SampleProject' }
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['d/Tests', ['b'].map { |n| n + '-Pods-SampleProject' }]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == %w(b base c e).map { |n| n + '-Pods-SampleProject' }
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'e-Pods-SampleProject' }
            pod_target.dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + '-Pods-SampleProject' }
            pod_target.recursive_dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + '-Pods-SampleProject' }
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == []
            pod_target.test_app_hosts_by_spec.should == {}

            pod_target = result.pod_targets.find { |pt| pt.name == 'app_host-Pods-SampleProject' }
            test_spec = pod_target.test_specs.find { |ts| ts.name == "#{pod_target.pod_name}/Tests" }
            app_spec = pod_target.app_specs.find { |as| as.name == "#{pod_target.pod_name}/App" }
            pod_target.dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + '-Pods-SampleProject' }
            pod_target.recursive_dependent_targets.map(&:name).sort.should == ['base'].map { |n| n + '-Pods-SampleProject' }
            pod_target.test_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['app_host/Tests', []]]
            pod_target.recursive_test_dependent_targets(test_spec).map(&:name).sort.should == []
            pod_target.app_dependent_targets_by_spec_name.map { |k, v| [k, v.map(&:name)] }.should == [['app_host/App', ['d'].map { |n| n + '-Pods-SampleProject' }]]
            pod_target.recursive_app_dependent_targets(app_spec).map(&:name).sort.should == %w(a b base c d e).map { |n| n + '-Pods-SampleProject' }
            pod_target.test_app_hosts_by_spec.map { |k, v| [k.name, v.map(&:name)] }.should == [['app_host/Tests', ['app_host/App', 'app_host-Pods-SampleProject']]]
          end

          it 'picks the right variants up when there are multiple' do
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'

              # The order of target definitions is important for this test.
              target 'TestRunner' do
                pod 'OrangeFramework'
                pod 'matryoshka/Foo'
              end

              target 'SampleProject' do
                pod 'OrangeFramework'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze

            result.targets.count.should == 2

            pod_target = result.targets[0].pod_targets.find { |pt| pt.pod_name == 'OrangeFramework' }
            pod_target.dependent_targets.count == 1
            pod_target.dependent_targets.first.specs.map(&:name).should == %w(
              matryoshka
              matryoshka/Foo
              matryoshka/Outer
              matryoshka/Outer/Inner
            )

            pod_target = result.targets[1].pod_targets.find { |pt| pt.pod_name == 'OrangeFramework' }
            pod_target.dependent_targets.count == 1
            pod_target.dependent_targets.first.specs.map(&:name).should == %w(
              matryoshka
              matryoshka/Outer
              matryoshka/Outer/Inner
            )
          end

          it 'does not create multiple variants across different targets that require different set of testspecs' do
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'

              target 'TestRunner' do
                pod 'CoconutLib', :testspecs => ['Tests']
              end

              target 'SampleProject' do
                pod 'CoconutLib'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze

            result.targets.count.should == 2
            result.targets[0].pod_targets.count == 1
            result.targets[0].pod_targets[0].name.should == 'CoconutLib-Pods-TestRunner'
            result.targets[1].pod_targets.count == 1
            result.targets[1].pod_targets[0].name.should == 'CoconutLib-Pods-SampleProject'
          end

          it 'sets the correct swift version' do
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'

              target 'SampleProject' do
                pod 'MultiSwift'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze

            result.targets.count.should == 1
            result.targets[0].pod_targets.count == 1
            result.targets[0].pod_targets[0].name.should == 'MultiSwift-Pods-SampleProject'
            result.targets[0].pod_targets[0].swift_version.should == '4.0'
          end

          it 'sets the correct swift version given podfile requirements' do
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              supports_swift_versions '< 4.0'
              project 'SampleProject/SampleProject'

              target 'SampleProject' do
                pod 'MultiSwift'
              end
            end
            @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil, [], true, false, @sources_manager)
            result = @analyzer.analyze

            result.targets.count.should == 1
            result.targets[0].pod_targets.count == 1
            result.targets[0].pod_targets[0].name.should == 'MultiSwift-Pods-SampleProject'
            result.targets[0].pod_targets[0].swift_version.should == '3.2'
          end
        end
      end

      describe 'deduplication' do
        it 'deduplicate targets if possible' do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '6.0'
            project 'SampleProject/SampleProject'

            target 'SampleProject' do
              pod 'BananaLib'
              pod 'monkey'

              target 'TestRunner' do
                pod 'BananaLib'
                pod 'monkey'
              end
            end

            target 'CLITool' do
              platform :osx, '10.10'
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.stubs(:sources_manager).returns(@sources_manager)
          result = analyzer.analyze

          pod_targets = result.targets.flat_map(&:pod_targets).uniq
          Hash[pod_targets.map { |t| [t.label, t.target_definitions.map(&:label).sort] }.sort].should == {
            'BananaLib'  => %w(Pods-SampleProject Pods-SampleProject-TestRunner),
            'monkey-iOS' => %w(Pods-SampleProject Pods-SampleProject-TestRunner),
            'monkey-macOS' => %w(Pods-CLITool),
          }
        end

        it "doesn't deduplicate targets across different integration modes" do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '6.0'
            xcodeproj 'SampleProject/SampleProject'
            target 'SampleProject' do
              use_frameworks!
              pod 'BananaLib'

              target 'TestRunner' do
                use_frameworks!(false)
                pod 'BananaLib'
              end
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.stubs(:sources_manager).returns(@sources_manager)
          result = analyzer.analyze

          pod_targets = result.targets.flat_map(&:pod_targets).uniq.sort_by(&:name)
          Hash[pod_targets.map { |t| [t.label, t.target_definitions.map(&:label)] }].should == {
            'BananaLib-library'   => %w(Pods-SampleProject-TestRunner),
            'BananaLib-framework' => %w(Pods-SampleProject),
            'monkey-library'      => %w(Pods-SampleProject-TestRunner),
            'monkey-framework'    => %w(Pods-SampleProject),
          }
        end

        it "doesn't deduplicate targets when deduplication is disabled" do
          podfile = Pod::Podfile.new do
            install! 'cocoapods', :deduplicate_targets => false

            source SpecHelper.test_repo_url
            platform :ios, '6.0'
            project 'SampleProject/SampleProject'

            pod 'BananaLib'

            target 'SampleProject' do
              target 'TestRunner' do
                pod 'BananaLib'
              end
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.stubs(:sources_manager).returns(@sources_manager)
          result = analyzer.analyze

          result.targets.flat_map { |at| at.pod_targets.map { |pt| "#{at.name}/#{pt.name}" } }.sort.should == %w(
            Pods-SampleProject-TestRunner/BananaLib-Pods-SampleProject-TestRunner
            Pods-SampleProject-TestRunner/monkey-Pods-SampleProject-TestRunner
            Pods-SampleProject/BananaLib-Pods-SampleProject
            Pods-SampleProject/monkey-Pods-SampleProject
          ).sort
        end

        it "doesn't deduplicate targets when deduplication is disabled and using frameworks" do
          podfile = Pod::Podfile.new do
            install! 'cocoapods', :deduplicate_targets => false

            source SpecHelper.test_repo_url
            platform :ios, '6.0'
            project 'SampleProject/SampleProject'

            use_frameworks!

            pod 'BananaLib'

            target 'SampleProject' do
              target 'TestRunner' do
                pod 'BananaLib'
              end
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.stubs(:sources_manager).returns(@sources_manager)
          result = analyzer.analyze

          result.targets.flat_map { |at| at.pod_targets.map { |pt| "#{at.name}/#{pt.name}" } }.sort.should == %w(
            Pods-SampleProject-TestRunner/BananaLib-Pods-SampleProject-TestRunner
            Pods-SampleProject-TestRunner/monkey-Pods-SampleProject-TestRunner
            Pods-SampleProject/BananaLib-Pods-SampleProject
            Pods-SampleProject/monkey-Pods-SampleProject
          ).sort

          result.targets.flat_map { |at| at.pod_targets.map(&:requires_frameworks?) }.uniq.should == [true]
        end
      end

      it 'generates the integration library appropriately if the installation will not integrate' do
        @analyzer.installation_options.integrate_targets = false
        target = @analyzer.analyze.targets.first

        target.client_root.should == config.installation_root
        target.user_target_uuids.should == []
        target.user_build_configurations.should == { 'Release' => :release, 'Debug' => :debug }
        target.platform.to_s.should == 'iOS 6.0'

        pod_target = target.pod_targets.first
        pod_target.user_build_configurations.should == { 'Release' => :release, 'Debug' => :debug }
      end

      describe 'no-integrate platform validation' do
        it 'does not require a platform for an empty target' do
          podfile = Pod::Podfile.new do
            install! 'cocoapods', :integrate_targets => false
            source SpecHelper.test_repo_url
            project 'SampleProject/SampleProject'
            target 'TestRunner' do
              platform :osx
              pod 'monkey'
            end
          end

          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.stubs(:sources_manager).returns(@sources_manager)
          lambda { analyzer.analyze }.should.not.raise
        end

        it 'does not raise if a target with dependencies inherits the platform from its parent' do
          podfile = Pod::Podfile.new do
            install! 'cocoapods', :integrate_targets => false
            source SpecHelper.test_repo_url
            project 'SampleProject/SampleProject'
            platform :osx
            target 'TestRunner' do
              pod 'monkey'
            end
          end

          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.stubs(:sources_manager).returns(@sources_manager)
          lambda { analyzer.analyze }.should.not.raise
        end

        it 'raises if a target with dependencies does not have a platform' do
          podfile = Pod::Podfile.new do
            install! 'cocoapods', :integrate_targets => false
            source SpecHelper.test_repo_url
            project 'SampleProject/SampleProject'
            target 'TestRunner' do
              pod 'monkey'
            end
          end

          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.stubs(:sources_manager).returns(@sources_manager)
          lambda { analyzer.analyze }.should.raise Informative
        end
      end

      it 'returns all the configurations the user has in any of its projects and/or targets' do
        target_definition = @analyzer.podfile.target_definition_list.first
        target_definition.stubs(:build_configurations).returns('AdHoc' => :test)
        @analyzer.analyze.all_user_build_configurations.should == {
          'Debug'     => :debug,
          'Release'   => :release,
          'AdHoc'     => :test,
          'Test'      => :release,
          'App Store' => :release,
        }
      end

      #--------------------------------------#

      it 'locks the version of the dependencies which did not change in the Podfile' do
        podfile_state = @analyzer.send(:generate_podfile_state)
        @analyzer.send(:generate_version_locking_dependencies, podfile_state).map(&:payload).map(&:to_s).should ==
            ['JSONKit (= 1.5pre)', 'SVPullToRefresh (= 0.4)']
      end

      it 'does not lock the dependencies in update mode' do
        @analyzer.stubs(:pods_to_update).returns(true)
        podfile_state = @analyzer.send(:generate_podfile_state)
        @analyzer.send(:generate_version_locking_dependencies, podfile_state).to_a.map(&:payload).should == []
      end

      it 'unlocks dependencies in a case-insensitive manner' do
        @analyzer.stubs(:pods_to_update).returns(:pods => %w(JSONKit))
        podfile_state = @analyzer.send(:generate_podfile_state)
        @analyzer.send(:generate_version_locking_dependencies, podfile_state).map(&:payload).map(&:to_s).should ==
            ['SVPullToRefresh (= 0.4)']
      end

      it 'unlocks dependencies when the local spec does not exist' do
        @analyzer.stubs(:pods_to_update).returns(:pods => %w(JSONKit))
        @analyzer.stubs(:podfile_dependencies).returns [Dependency.new('foo', :path => 'Foo.podspec')]
        config.sandbox.stubs(:specification).returns(nil)
        podfile_state = @analyzer.send(:generate_podfile_state)
        @analyzer.send(:generate_version_locking_dependencies, podfile_state).map(&:payload).map(&:to_s).should ==
            ['SVPullToRefresh (= 0.4)']
      end

      it 'unlocks all dependencies with the same root name in update mode' do
        podfile = Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          target 'SampleProject' do
            pod 'AFNetworking'
            pod 'AFNetworkActivityLogger'
          end
        end
        hash = {}
        hash['PODS'] = [
          { 'AFNetworkActivityLogger (2.0.3)' => ['AFNetworking/NSURLConnection (~> 2.0)', 'AFNetworking/NSURLSession (~> 2.0)'] },
          { 'AFNetworking (2.4.0)' => ['AFNetworking/NSURLConnection (= 2.4.0)', 'AFNetworking/NSURLSession (= 2.4.0)', 'AFNetworking/Reachability (= 2.4.0)', 'AFNetworking/Security (= 2.4.0)', 'AFNetworking/Serialization (= 2.4.0)', 'AFNetworking/UIKit (= 2.4.0)'] },
          { 'AFNetworking/NSURLConnection (2.4.0)' => ['AFNetworking/Reachability', 'AFNetworking/Security', 'AFNetworking/Serialization'] },
          { 'AFNetworking/NSURLSession (2.4.0)' => ['AFNetworking/Reachability', 'AFNetworking/Security', 'AFNetworking/Serialization'] },
          'AFNetworking/Reachability (2.4.0)',
          'AFNetworking/Security (2.4.0)',
          'AFNetworking/Serialization (2.4.0)',
          { 'AFNetworking/UIKit (2.4.0)' => ['AFNetworking/NSURLConnection', 'AFNetworking/NSURLSession'] },
        ]
        hash['DEPENDENCIES'] = ['AFNetworkActivityLogger', 'AFNetworking (2.4.0)']
        hash['SPEC CHECKSUMS'] = {}
        hash['COCOAPODS'] = Pod::VERSION
        lockfile = Pod::Lockfile.new(hash)
        analyzer = Installer::Analyzer.new(config.sandbox, podfile, lockfile, nil, true, :pods => %w(AFNetworking))

        analyzer.analyze.specifications.
          find { |s| s.name == 'AFNetworking' }.
          version.to_s.should == '2.7.0'
      end

      it 'unlocks only local pod when specification checksum changes' do
        sandbox = config.sandbox
        local_spec = Specification.from_hash('name' => 'LocalPod', 'version' => '1.1', 'dependencies' => { 'Expecta' => ['~> 0.0'] })
        sandbox.stubs(:specification).with('LocalPod').returns(local_spec)
        podfile = Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          target 'SampleProject' do
            pod 'LocalPod', :path => '../'
          end
        end
        hash = {}
        hash['PODS'] = ['Expecta (0.2.0)', { 'LocalPod (1.0)' => ['Expecta (~> 0.0)'] }]
        hash['DEPENDENCIES'] = ['LocalPod (from `../`)']
        hash['EXTERNAL SOURCES'] = { 'LocalPod' => { :path => '../' } }
        hash['SPEC CHECKSUMS'] = { 'LocalPod' => 'DUMMY_CHECKSUM' }
        hash['COCOAPODS'] = Pod::VERSION
        lockfile = Pod::Lockfile.new(hash)
        analyzer = Installer::Analyzer.new(sandbox, podfile, lockfile)
        analyzer.analyze(false).specifications.
          find { |s| s.name == 'LocalPod' }.
          version.to_s.should == '1.1'
        analyzer.analyze(false).specifications.
          find { |s| s.name == 'Expecta' }.
          version.to_s.should == '0.2.0'
      end

      it 'raises if change in local pod specification conflicts with lockfile' do
        sandbox = config.sandbox
        local_spec = Specification.from_hash('name' => 'LocalPod', 'version' => '1.0', 'dependencies' => { 'Expecta' => ['0.2.2'] })
        sandbox.stubs(:specification).with('LocalPod').returns(local_spec)
        podfile = Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          target 'SampleProject' do
            pod 'LocalPod', :path => '../'
          end
        end
        hash = {}
        hash['PODS'] = ['Expecta (0.2.0)', { 'LocalPod (1.0)' => ['Expecta (=0.2.0)'] }]
        hash['DEPENDENCIES'] = ['LocalPod (from `../`)']
        hash['EXTERNAL SOURCES'] = { 'LocalPod' => { :path => '../' } }
        hash['SPEC CHECKSUMS'] = {}
        hash['COCOAPODS'] = Pod::VERSION
        lockfile = Pod::Lockfile.new(hash)
        analyzer = Installer::Analyzer.new(sandbox, podfile, lockfile)
        should.raise(Informative) do
          analyzer.analyze(false)
        end.message.should.match /You should run `pod update Expecta`/
      end

      it 'raises if dependencies need to be fetched but fetching is not allowed' do
        sandbox = config.sandbox
        podfile = Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          target 'SampleProject' do
            pod 'ExternalSourcePod', :podspec => 'ExternalSourcePod.podspec'
          end
        end

        hash = {}
        hash['PODS'] = ['Expecta (0.2.0)', { 'ExternalSourcePod (1.0)' => ['Expecta (=0.2.0)'] }]
        hash['DEPENDENCIES'] = ['ExternalSourcePod (from `ExternalSourcePod.podspec`)']
        hash['EXTERNAL SOURCES'] = { 'ExternalSourcePod' => { :podspec => 'ExternalSourcePod.podspec' } }
        hash['SPEC CHECKSUMS'] = { 'ExternalSourcePod' => 'DUMMY_CHECKSUM' }
        hash['COCOAPODS'] = Pod::VERSION
        lockfile = Lockfile.new(hash)

        analyzer = Installer::Analyzer.new(sandbox, podfile, lockfile)
        error = should.raise(Informative) do
          analyzer.analyze(false)
        end
        error.message.should.include \
          'Cannot analyze without fetching dependencies since the sandbox is not up-to-date. Run `pod install` to ensure all dependencies have been fetched.'
      end

      #--------------------------------------#

      it 'takes into account locked implicit dependencies' do
        podfile = Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          target 'SampleProject' do
            pod 'ARAnalytics/Mixpanel'
          end
        end
        hash = {}
        hash['PODS'] = ['ARAnalytics/CoreIOS (2.8.0)', { 'ARAnalytics/Mixpanel (2.8.0)' => ['ARAnlytics/CoreIOS', 'Mixpanel'] }, 'Mixpanel (2.5.1)']
        hash['DEPENDENCIES'] = %w(ARAnalytics/Mixpanel)
        hash['SPEC CHECKSUMS'] = {}
        hash['COCOAPODS'] = Pod::VERSION
        lockfile = Pod::Lockfile.new(hash)
        analyzer = Installer::Analyzer.new(config.sandbox, podfile, lockfile)

        analyzer.analyze.specifications.
          find { |s| s.name == 'Mixpanel' }.
          version.to_s.should == '2.5.1'
      end

      it 'takes into account locked dependency spec repos' do
        podfile = Podfile.new do
          platform :ios, '8.0'
          project 'SampleProject/SampleProject'
          source 'https://example.com/example/specs.git'
          source Pod::TrunkSource::TRUNK_REPO_URL
          target 'SampleProject' do
            pod 'JSONKit', '1.5pre'
          end
        end
        hash = {}
        hash['PODS'] = ['JSONKit (1.5pre)']
        hash['DEPENDENCIES'] = %w(JSONKit)
        hash['SPEC CHECKSUMS'] = {}
        hash['SPEC REPOS'] = {
          Pod::TrunkSource::TRUNK_REPO_URL => ['JSONKit'],
        }
        hash['COCOAPODS'] = Pod::VERSION
        lockfile = Pod::Lockfile.new(hash)
        analyzer = Installer::Analyzer.new(config.sandbox, podfile, lockfile)
        analyzer.stubs(:sources_manager).returns(@sources_manager)
        example_source = MockSource.new 'example-example-specs' do
          pod 'JSONKit', '1.5pre' do |s|
            s.dependency 'Nope', '1.0'
          end

          pod 'Nope', '1.0' do |s|
            s.ios.deployment_target = '8'
          end
        end
        master_source = analyzer.sources_manager.master.first

        analyzer.stubs(:sources).returns([example_source, master_source])
        # if we prefered the first source (the default), we also would have resolved Nope
        analyzer.analyze.specs_by_source.
          should == {
            example_source => [],
            master_source => [Pod::Spec.new(nil, 'JSONKit') { |s| s.version = '1.5pre' }],
          }
      end

      #--------------------------------------#

      it 'fetches the dependencies with external sources' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.added << 'BananaLib'
        @podfile = Podfile.new do
          pod 'BananaLib', :git => 'example.com'
        end
        @analyzer = Installer::Analyzer.new(@sandbox, @podfile)
        ExternalSources::DownloaderSource.any_instance.expects(:fetch)
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      it 'does not download the same source multiple times for different subspecs' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.added << 'ARAnalytics'
        @podfile = Podfile.new do
          pod 'ARAnalytics/Mixpanel', :git => 'https://github.com/orta/ARAnalytics', :commit => '6f1a1c314894437e7e5c09572c276e644dbfb64b'
          pod 'ARAnalytics/HockeyApp', :git => 'https://github.com/orta/ARAnalytics', :commit => '6f1a1c314894437e7e5c09572c276e644dbfb64b'
        end
        @analyzer = Installer::Analyzer.new(@sandbox, @podfile)
        ExternalSources::DownloaderSource.any_instance.expects(:fetch).once
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      #--------------------------------------#

      it 'resolves the dependencies' do
        @analyzer.analyze.specifications.map(&:to_s).should == [
          'AFNetworking (1.0.1)',
          'JSONKit (1.5pre)',
          'SVPullToRefresh (0.4)',
          'libextobjc/EXTKeyPathCoding (0.2.3)',
          'libextobjc/EXTSynthesize (0.2.3)',
        ]
      end

      it 'adds the specifications to the correspondent libraries' do
        @analyzer.analyze.targets[0].pod_targets.map(&:specs).flatten.map(&:to_s).should == [
          'AFNetworking (1.0.1)',
          'JSONKit (1.5pre)',
          'SVPullToRefresh (0.4)',
          'libextobjc/EXTKeyPathCoding (0.2.3)',
        ]
        @analyzer.analyze.targets[1].pod_targets.map(&:specs).flatten.map(&:to_s).should == [
          'libextobjc/EXTKeyPathCoding (0.2.3)',
          'libextobjc/EXTSynthesize (0.2.3)',
        ]
      end

      #--------------------------------------#

      it 'warns when a dependency is duplicated' do
        podfile = Podfile.new do
          project 'SampleProject/SampleProject'
          platform :ios, '8.0'
          target 'SampleProject' do
            pod 'RestKit', '~> 0.23.0'
            pod 'RestKit', '<= 0.23.2'
          end
        end
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        analyzer.analyze

        UI.warnings.should.match /duplicate dependencies on `RestKit`/
        UI.warnings.should.match /RestKit \(~> 0.23.0\)/
        UI.warnings.should.match /RestKit \(<= 0.23.2\)/
      end

      it 'raises when specs have incompatible cocoapods requirements' do
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
        Specification.any_instance.stubs(:cocoapods_version).returns(Requirement.create '= 0.1.0')
        should.raise(Informative) { analyzer.analyze }
      end

      #--------------------------------------#

      it 'computes the state of the Sandbox respect to the resolved dependencies' do
        @analyzer.stubs(:lockfile).returns(nil)
        state = @analyzer.analyze.sandbox_state
        state.added.sort.should == %w(AFNetworking JSONKit SVPullToRefresh libextobjc)
      end

      #-------------------------------------------------------------------------#

      describe '#group_pod_targets_by_target_definition' do
        it 'does include pod target if any spec is not used by tests only and is part of target definition' do
          spec1 = Resolver::ResolverSpecification.new(stub(:root => stub(:name => 'Pod1')), false, nil)
          spec2 = Resolver::ResolverSpecification.new(stub(:root => stub(:name => 'Pod1')), true, nil)
          target_definition = @podfile.target_definitions['SampleProject']
          pod_target = stub(:name => 'Pod1', :target_definitions => [target_definition], :specs => [spec1.spec, spec2.spec], :pod_name => 'Pod1')
          resolver_specs_by_target = { target_definition => [spec1, spec2] }
          @analyzer.send(:group_pod_targets_by_target_definition, [pod_target], resolver_specs_by_target).should == { target_definition => [pod_target] }
        end

        it 'does not include pod target if its used by tests only' do
          spec1 = Resolver::ResolverSpecification.new(stub(:root => stub(:name => 'Pod1')), true, nil)
          spec2 = Resolver::ResolverSpecification.new(stub(:root => stub(:name => 'Pod1')), true, nil)
          target_definition = stub('TargetDefinition')
          pod_target = stub(:name => 'Pod1', :target_definitions => [target_definition], :specs => [spec1.spec, spec2.spec], :pod_name => 'Pod1')
          resolver_specs_by_target = { target_definition => [spec1, spec2] }
          @analyzer.send(:group_pod_targets_by_target_definition, [pod_target], resolver_specs_by_target).should == { target_definition => [] }
        end

        it 'does not include pod target if its not part of the target definition' do
          spec = Resolver::ResolverSpecification.new(stub(:root => stub(:name => 'Pod1')), false, nil)
          target_definition = stub
          pod_target = stub(:name => 'Pod1', :target_definitions => [], :specs => [spec.spec])
          resolver_specs_by_target = { target_definition => [spec] }
          @analyzer.send(:group_pod_targets_by_target_definition, [pod_target], resolver_specs_by_target).should == { target_definition => [] }
        end
      end

      describe '#filter_pod_targets_for_target_definition' do
        it 'returns whether it is whitelisted in a build configuration' do
          target_definition = @podfile.target_definitions['SampleProject']
          target_definition.whitelist_pod_for_configuration('JSONKit', 'Debug')

          aggregate_target = @analyzer.analyze.targets.find { |t| t.target_definition == target_definition }
          aggregate_target.pod_targets_for_build_configuration('Debug').map(&:name).
            should.include 'JSONKit'
          aggregate_target.pod_targets_for_build_configuration('Release').map(&:name).
            should.not.include 'JSONKit'
        end

        it 'allows a pod that is a dependency for other pods to be whitelisted' do
          @podfile = Podfile.new do
            platform :ios, '8.0'
            project 'SampleProject/SampleProject'
            target 'SampleProject' do
              pod 'AFNetworking', :configuration => 'Debug'
              pod 'AFNetworkActivityLogger'
            end
          end
          @analyzer = Installer::Analyzer.new(config.sandbox, @podfile)
          target_definition = @podfile.target_definitions['SampleProject']
          aggregate_target = @analyzer.analyze.targets.find { |t| t.target_definition == target_definition }

          aggregate_target.pod_targets_for_build_configuration('Debug').map(&:name).
            should.include 'AFNetworking'
          aggregate_target.pod_targets_for_build_configuration('Release').map(&:name).
            should.not.include 'AFNetworking'
        end

        it 'raises if a Pod is whitelisted for different build configurations' do
          @podfile = Podfile.new do
            platform :ios, '8.0'
            project 'SampleProject/SampleProject'
            target 'SampleProject' do
              pod 'AFNetworking'
              pod 'AFNetworking/NSURLConnection', :configuration => 'Debug'
              pod 'AFNetworkActivityLogger'
            end
          end
          @analyzer = Installer::Analyzer.new(config.sandbox, @podfile)

          should.raise(Informative) do
            @analyzer.analyze
          end.message.should.include 'The subspecs of `AFNetworking` are linked to different build configurations for the `Pods-SampleProject` target. CocoaPods does not currently support subspecs across different build configurations.'
        end
      end

      #-------------------------------------------------------------------------#

      describe 'extension targets' do
        before do
          SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project')
          @podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '6.0'
            project 'Sample Extensions Project/Sample Extensions Project'
            pod 'matryoshka/Bar'

            target 'Sample Extensions Project' do
              pod 'JSONKit', '1.4'
              pod 'matryoshka/Foo'
            end

            target 'Today Extension' do
              pod 'monkey'
            end
          end
          Pod::Installer::Analyzer.any_instance.stubs(:sources_manager).returns(@sources_manager)
        end

        it 'copies extension pod targets to host target, when use_frameworks!' do
          @podfile.use_frameworks!
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
          result = analyzer.analyze

          result.targets.flat_map { |at| at.pod_targets.map { |pt| "#{at.name}/#{pt.name}" } }.sort.should == [
            'Pods-Sample Extensions Project/JSONKit',
            'Pods-Sample Extensions Project/matryoshka-Bar-Foo',
            'Pods-Sample Extensions Project/monkey',
            'Pods-Today Extension/matryoshka-Bar',
            'Pods-Today Extension/monkey',
          ].sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Debug').map { |pt| "#{at.name}/Debug/#{pt.name}" } }.sort.should == [
            'Pods-Sample Extensions Project/Debug/JSONKit',
            'Pods-Sample Extensions Project/Debug/matryoshka-Bar-Foo',
            'Pods-Sample Extensions Project/Debug/monkey',
            'Pods-Today Extension/Debug/matryoshka-Bar',
            'Pods-Today Extension/Debug/monkey',
          ].sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Release').map { |pt| "#{at.name}/Release/#{pt.name}" } }.sort.should == [
            'Pods-Sample Extensions Project/Release/JSONKit',
            'Pods-Sample Extensions Project/Release/matryoshka-Bar-Foo',
            'Pods-Sample Extensions Project/Release/monkey',
            'Pods-Today Extension/Release/matryoshka-Bar',
            'Pods-Today Extension/Release/monkey',
          ].sort
        end

        it 'does not copy extension pod targets to host target, when not use_frameworks!' do
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
          result = analyzer.analyze

          result.targets.flat_map { |at| at.pod_targets.map { |pt| "#{at.name}/#{pt.name}" } }.sort.should == [
            'Pods-Sample Extensions Project/JSONKit',
            'Pods-Sample Extensions Project/matryoshka-Bar-Foo',
            'Pods-Today Extension/matryoshka-Bar',
            'Pods-Today Extension/monkey',
          ].sort
        end

        it 'does not copy extension pod targets to host target, when use_frameworks! but contained pod is static' do
          SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project')
          fixture_path = ROOT + 'spec/fixtures'
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '6.0'
            project 'Sample Extensions Project/Sample Extensions Project'
            use_frameworks!

            target 'Sample Extensions Project' do
              pod 'JSONKit', '1.4'
            end

            target 'Today Extension' do
              pod 'matryoshka', :path => (fixture_path + 'static-matryoshka').to_s
            end
          end

          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          # Create 'Local Podspecs' folder within target project
          Dir.mkdir(File.join(config.sandbox.root, 'Local Podspecs'))
          result = analyzer.analyze

          result.targets.flat_map { |at| at.pod_targets.map { |pt| "#{at.name}/#{pt.name}" } }.sort.should == [
            'Pods-Sample Extensions Project/JSONKit',
            'Pods-Sample Extensions Project/monkey',
            'Pods-Today Extension/monkey',
            'Pods-Today Extension/matryoshka',
          ].sort
        end

        it 'copies pod targets of frameworks and libraries from within sub projects' do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            use_frameworks!
            platform :ios, '8.0'
            project 'SampleProject/SampleProject'

            target 'SampleProject' do
              pod 'JSONKit'
            end

            target 'SampleFramework' do
              project 'SampleProject/Sample Lib/Sample Lib'
              pod 'monkey'
            end

            target 'SampleLib' do
              project 'SampleProject/Sample Lib/Sample Lib'
              pod 'matryoshka'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          result = analyzer.analyze

          result.targets.select { |at| at.name == 'Pods-SampleProject' }.flat_map(&:pod_targets).map(&:name).sort.uniq.should == %w(
            JSONKit
            matryoshka
            monkey
          ).sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Debug').map { |pt| "#{at.name}/Debug/#{pt.name}" } }.sort.should == [
            'Pods-SampleFramework/Debug/monkey',
            'Pods-SampleLib/Debug/matryoshka',
            'Pods-SampleProject/Debug/JSONKit',
            'Pods-SampleProject/Debug/matryoshka',
            'Pods-SampleProject/Debug/monkey',
          ].sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Release').map { |pt| "#{at.name}/Release/#{pt.name}" } }.sort.should == [
            'Pods-SampleFramework/Release/monkey',
            'Pods-SampleLib/Release/matryoshka',
            'Pods-SampleProject/Release/JSONKit',
            'Pods-SampleProject/Release/matryoshka',
            'Pods-SampleProject/Release/monkey',
          ].sort
        end

        it "copy a framework's pod target, when the framework is in a sub project and is scoped to a configuration" do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            use_frameworks!
            platform :ios, '8.0'
            project 'SampleProject/SampleProject'

            target 'SampleProject' do
              pod 'JSONKit'
            end

            target 'SampleFramework' do
              project 'SampleProject/Sample Lib/Sample Lib'
              pod 'monkey', :configurations => ['Debug']
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          result = analyzer.analyze

          result.targets.select { |at| at.name == 'Pods-SampleProject' }.flat_map(&:pod_targets).map(&:name).sort.uniq.should == %w(
            JSONKit
            monkey
          ).sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Debug').map { |pt| "#{at.name}/Debug/#{pt.name}" } }.sort.should == [
            'Pods-SampleFramework/Debug/monkey',
            'Pods-SampleProject/Debug/JSONKit',
            'Pods-SampleProject/Debug/monkey',
          ].sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Release').map { |pt| "#{at.name}/Release/#{pt.name}" } }.sort.should == [
            'Pods-SampleProject/Release/JSONKit',
          ].sort
        end

        it "copy a static library's pod target, when the static library is in a sub project" do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '8.0'
            project 'SampleProject/SampleProject'
            pod 'matryoshka/Bar'

            target 'SampleProject' do
              pod 'JSONKit'
              pod 'matryoshka/Foo'
            end

            target 'SampleLib' do
              project 'SampleProject/Sample Lib/Sample Lib'
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          result = analyzer.analyze

          result.targets.select { |at| at.name == 'Pods-SampleProject' }.flat_map(&:pod_targets).map(&:name).sort.uniq.should == %w(
            JSONKit
            matryoshka-Bar-Foo
            monkey
          ).sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Debug').map { |pt| "#{at.name}/Debug/#{pt.name}" } }.sort.should == [
            'Pods-SampleLib/Debug/matryoshka-Bar',
            'Pods-SampleLib/Debug/monkey',
            'Pods-SampleProject/Debug/JSONKit',
            'Pods-SampleProject/Debug/matryoshka-Bar-Foo',
            'Pods-SampleProject/Debug/monkey',
          ].sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Release').map { |pt| "#{at.name}/Release/#{pt.name}" } }.sort.should == [
            'Pods-SampleLib/Release/matryoshka-Bar',
            'Pods-SampleLib/Release/monkey',
            'Pods-SampleProject/Release/JSONKit',
            'Pods-SampleProject/Release/matryoshka-Bar-Foo',
            'Pods-SampleProject/Release/monkey',
          ].sort
        end

        it "copy a static library's pod target, when the static library is in a sub project and is scoped to a configuration" do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '8.0'
            project 'SampleProject/SampleProject'

            target 'SampleProject' do
              pod 'JSONKit'
            end

            target 'SampleLib' do
              project 'SampleProject/Sample Lib/Sample Lib'
              pod 'monkey', :configuration => ['Debug']
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          result = analyzer.analyze

          result.targets.select { |at| at.name == 'Pods-SampleProject' }.flat_map(&:pod_targets).map(&:name).sort.uniq.should == %w(
            JSONKit
            monkey
          ).sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Debug').map { |pt| "#{at.name}/Debug/#{pt.name}" } }.sort.should == [
            'Pods-SampleLib/Debug/monkey',
            'Pods-SampleProject/Debug/JSONKit',
            'Pods-SampleProject/Debug/monkey',
          ].sort
          result.targets.flat_map { |at| at.pod_targets_for_build_configuration('Release').map { |pt| "#{at.name}/Release/#{pt.name}" } }.sort.should == [
            'Pods-SampleProject/Release/JSONKit',
          ].sort
        end

        it "does not copy a static library's pod target, when the static library aggregate target has search paths inherited" do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '8.0'

            target 'SampleLib' do
              project 'SampleProject/Sample Lib/Sample Lib'
              pod 'monkey'

              target 'SampleProject' do
                inherit! :search_paths
                project 'SampleProject/SampleProject'
                pod 'JSONKit'
              end
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          result = analyzer.analyze

          result.targets.flat_map do |aggregate_target|
            aggregate_target.pod_targets.flat_map { |pt| "#{aggregate_target}/#{pt}" }
          end.sort.should == [
            'Pods-SampleLib/monkey',
            'Pods-SampleProject/JSONKit',
          ]
        end

        it "raises when unable to find an extension's host target" do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            use_frameworks!
            platform :ios, '8.0'
            project 'Sample Extensions Project/Sample Extensions Project'

            target 'Today Extension' do
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          should.raise Informative do
            analyzer.analyze
          end.message.should.match /Unable to find host target\(s\) for Today Extension. Please add the host targets for the embedded targets to the Podfile\./
        end

        it 'warns when using a Podfile for framework-only projects' do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            use_frameworks!
            platform :ios, '8.0'
            target 'SampleLib' do
              project 'SampleProject/Sample Lib/Sample Lib'
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.analyze
          UI.warnings.should.match /The Podfile contains framework or static library targets \(SampleLib\), for which the Podfile does not contain host targets \(targets which embed the framework\)\./
        end

        it 'warns when using dynamic frameworks with CLI targets' do
          project_path = fixture('Sample Extensions Project/Sample Extensions Project')
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '8.0'
            project project_path
            target 'SampleCommandLineTool' do
              use_frameworks!
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.analyze
          UI.warnings.should.match /The Podfile contains command line tool target\(s\) \(SampleCommandLineTool\) which are attempting to integrate dynamic frameworks or libraries\./
        end

        it 'does not warn when using static libraries with CLI targets' do
          project_path = fixture('Sample Extensions Project/Sample Extensions Project')
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '8.0'
            project project_path
            target 'SampleCommandLineTool' do
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          analyzer.analyze
          UI.warnings.should.be.empty?
        end

        it 'raises when the extension calls use_frameworks!, but the host target does not' do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '8.0'
            project 'Sample Extensions Project/Sample Extensions Project'

            target 'Sample Extensions Project' do
              pod 'JSONKit', '1.4'
            end

            target 'Today Extension' do
              use_frameworks!
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          should.raise Informative do
            analyzer.analyze
          end.message.should.match /Sample Extensions Project \(false\) and Today Extension \(true\) do not both set use_frameworks!\./
        end

        describe 'APPLICATION_EXTENSION_API_ONLY' do
          it 'configures APPLICATION_EXTENSION_API_ONLY for app extension targets' do
            @podfile.use_frameworks!
            analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
            result = analyzer.analyze

            result.targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['Pods-Sample Extensions Project', false], ['Pods-Today Extension', true]]
            result.pod_targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['matryoshka-Bar', true], ['matryoshka-Bar-Foo', false], ['JSONKit', false], ['monkey', true]]
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for watch app extension targets' do
            @user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project'))
            targets = @user_project.targets
            targets.delete(targets.find('Sample Extensions Project').first)
            extension_target = targets.find('Today Extension').first
            extension_target.product_type = 'com.apple.product-type.watchkit2-extension'
            extension_target.name = 'watchOS Extension Target'
            extension_target.symbol_type.should == :watch2_extension
            @user_project.save
            project_path = @user_project.path
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :watchos, '2.0'
              project project_path

              target 'watchOS Extension Target' do
                use_frameworks!
                pod 'monkey'
              end
            end

            @podfile.use_frameworks!
            analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
            result = analyzer.analyze

            result.targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['Pods-watchOS Extension Target', true]]
            result.pod_targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['monkey', true]]
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for TV app extension targets' do
            @user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project'))
            targets = @user_project.targets
            targets.delete(targets.find('Sample Extensions Project').first)
            extension_target = targets.find('Today Extension').first
            extension_target.product_type = 'com.apple.product-type.tv-app-extension'
            extension_target.name = 'tvOS Extension Target'
            extension_target.symbol_type.should == :tv_extension
            @user_project.save
            project_path = @user_project.path
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :tvos, '9.0'
              project project_path

              target 'tvOS Extension Target' do
                use_frameworks!
                pod 'monkey'
              end
            end

            @podfile.use_frameworks!
            analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
            result = analyzer.analyze

            result.targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['Pods-tvOS Extension Target', true]]
            result.pod_targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['monkey', true]]
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY for messages extension targets' do
            @user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project'))
            targets = @user_project.targets
            app_target = targets.find { |t| t.name == 'Sample Extensions Project' }
            app_target.product_type = 'com.apple.product-type.application.messages'
            extension_target = targets.find { |t| t.name == 'Today Extension' }
            extension_target.product_type = 'com.apple.product-type.app-extension.messages'
            extension_target.name = 'Messages Extension Target'
            extension_target.symbol_type.should == :messages_extension
            @user_project.save
            project_path = @user_project.path
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project project_path

              target 'Sample Extensions Project' do
                pod 'JSONKit', '1.4'
              end

              target 'Messages Extension Target' do
                use_frameworks!
                pod 'monkey'
              end
            end

            @podfile.use_frameworks!
            analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
            result = analyzer.analyze

            result.targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['Pods-Sample Extensions Project', false], ['Pods-Messages Extension Target', true]]
            result.pod_targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['JSONKit', false], ['monkey', true]]
          end

          it 'configures APPLICATION_EXTENSION_API_ONLY when build setting is set in user target' do
            @user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project'))
            targets = @user_project.targets
            app_target = targets.find { |t| t.name == 'Sample Extensions Project' }
            app_target.build_configurations.each { |c| c.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES' }
            @user_project.save
            project_path = @user_project.path
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project project_path

              target 'Sample Extensions Project' do
                pod 'JSONKit', '1.4'
              end

              target 'Today Extension' do
                use_frameworks!
                pod 'monkey'
              end
            end

            @podfile.use_frameworks!
            analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
            result = analyzer.analyze

            result.targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['Pods-Sample Extensions Project', true], ['Pods-Today Extension', true]]
            result.pod_targets.map { |t| [t.name, t.application_extension_api_only] }.
              should == [['JSONKit', true], ['monkey', true]]
          end
        end

        it 'configures APPLICATION_EXTENSION_API_ONLY when build setting is set in user target xcconfig' do
          @user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project'))
          targets = @user_project.targets
          app_target = targets.find { |t| t.name == 'Sample Extensions Project' }
          sample_config = @user_project.new_file('App.xcconfig')
          File.write(sample_config.real_path, 'APPLICATION_EXTENSION_API_ONLY=YES')
          app_target.build_configurations.each do |config|
            config.base_configuration_reference = sample_config
          end
          @user_project.save
          project_path = @user_project.path
          @podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '8.0'
            project project_path

            target 'Sample Extensions Project' do
              pod 'JSONKit', '1.4'
            end

            target 'Today Extension' do
              use_frameworks!
              pod 'monkey'
            end
          end

          @podfile.use_frameworks!
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
          result = analyzer.analyze

          result.targets.map { |t| [t.name, t.application_extension_api_only] }.
            should == [['Pods-Sample Extensions Project', true], ['Pods-Today Extension', true]]
          result.pod_targets.map { |t| [t.name, t.application_extension_api_only] }.
            should == [['JSONKit', true], ['monkey', true]]
        end

        describe 'BUILD_LIBRARY_FOR_DISTRIBUTION' do
          it 'configures BUILD_LIBRARY_FOR_DISTRIBUTION when build setting is set in user target' do
            @user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project'))
            targets = @user_project.targets
            app_target = targets.find { |t| t.name == 'Sample Extensions Project' }
            app_target.build_configurations.each { |c| c.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES' }
            app_target = targets.find { |t| t.name == 'Today Extension' }
            app_target.build_configurations.each { |c| c.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES' }
            @user_project.save
            project_path = @user_project.path
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project project_path

              target 'Sample Extensions Project' do
                pod 'JSONKit', '1.4'
              end

              target 'Today Extension' do
                use_frameworks!
                pod 'monkey'
              end
            end

            @podfile.use_frameworks!
            analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
            result = analyzer.analyze

            result.targets.map { |t| [t.name, t.build_library_for_distribution] }.
              should == [['Pods-Sample Extensions Project', true], ['Pods-Today Extension', true]]
            result.pod_targets.map { |t| [t.name, t.build_library_for_distribution] }.
              should == [['JSONKit', true], ['monkey', true]]
          end

          it 'configures BUILD_LIBRARY_FOR_DISTRIBUTION when build setting is set in user target xcconfig' do
            @user_project = Xcodeproj::Project.open(SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project'))
            sample_config = @user_project.new_file('App.xcconfig')
            File.write(sample_config.real_path, 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES')
            targets = @user_project.targets
            app_target = targets.find { |t| t.name == 'Sample Extensions Project' }
            app_target.build_configurations.each do |config|
              config.base_configuration_reference = sample_config
            end
            app_target = targets.find { |t| t.name == 'Today Extension' }
            app_target.build_configurations.each do |config|
              config.base_configuration_reference = sample_config
            end
            @user_project.save
            project_path = @user_project.path
            @podfile = Pod::Podfile.new do
              source SpecHelper.test_repo_url
              platform :ios, '8.0'
              project project_path

              target 'Sample Extensions Project' do
                pod 'JSONKit', '1.4'
              end

              target 'Today Extension' do
                use_frameworks!
                pod 'monkey'
              end
            end

            @podfile.use_frameworks!
            analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
            result = analyzer.analyze

            result.targets.map { |t| [t.name, t.build_library_for_distribution] }.
              should == [['Pods-Sample Extensions Project', true], ['Pods-Today Extension', true]]
            result.pod_targets.map { |t| [t.name, t.build_library_for_distribution] }.
              should == [['JSONKit', true], ['monkey', true]]
          end
        end
      end

      #-------------------------------------------------------------------------#

      describe 'Private helpers' do
        describe '#sources' do
          describe 'when there are no explicit sources' do
            it 'defaults to the master spec repository' do
              @analyzer.send(:sources).map(&:url).should == [Pod::TrunkSource::TRUNK_REPO_URL]
            end
          end

          describe 'when there are explicit sources' do
            it 'raises if no specs repo with that URL could be added' do
              podfile = Podfile.new do
                source 'not-a-git-repo'
                pod 'JSONKit', '1.4'
              end
              @analyzer.instance_variable_set(:@podfile, podfile)
              should.raise Informative do
                @analyzer.send(:sources)
              end.message.should.match /Unable to add/
            end

            it 'fetches a specs repo that is specified by the podfile' do
              podfile = Podfile.new do
                source 'https://github.com/artsy/Specs.git'
                pod 'JSONKit', '1.4'
              end
              @analyzer.instance_variable_set(:@podfile, podfile)
              @analyzer.sources_manager.expects(:find_or_create_source_with_url).once
              @analyzer.send(:sources)
            end
          end
        end
      end
    end

    describe 'Analysis, concerning naming' do
      before do
        SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
      end

      it 'raises when dependencies with the same name have different ' \
        'external sources' do
        podfile = Podfile.new do
          source Pod::TrunkSource::TRUNK_REPO_URL
          project 'SampleProject/SampleProject'
          platform :ios
          target 'SampleProject' do
            pod 'SEGModules', :git => 'https://github.com/segiddins/SEGModules.git'
            pod 'SEGModules', :git => 'https://github.com/segiddins/Modules.git'
          end
        end
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        e = should.raise(Informative) { analyzer.analyze }

        e.message.should.match /different sources for `SEGModules`/
        e.message.should.match %r{SEGModules \(from `https://github.com/segiddins/SEGModules.git`\)}
        e.message.should.match %r{SEGModules \(from `https://github.com/segiddins/Modules.git`\)}
      end

      it 'raises when dependencies with the same root name have different ' \
        'external sources' do
        podfile = Podfile.new do
          source Pod::TrunkSource::TRUNK_REPO_URL
          project 'SampleProject/SampleProject'
          platform :ios
          target 'SampleProject' do
            pod 'RestKit/Core', :git => 'https://github.com/RestKit/RestKit.git'
            pod 'RestKit', :git => 'https://github.com/segiddins/RestKit.git'
          end
        end
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        e = should.raise(Informative) { analyzer.analyze }

        e.message.should.match /different sources for `RestKit`/
        e.message.should.match %r{RestKit/Core \(from `https://github.com/RestKit/RestKit.git`\)}
        e.message.should.match %r{RestKit \(from `https://github.com/segiddins/RestKit.git`\)}
      end

      it 'raises when dependencies with the same name have different ' \
        'external sources with one being nil' do
        podfile = Podfile.new do
          source Pod::TrunkSource::TRUNK_REPO_URL
          project 'SampleProject/SampleProject'
          platform :ios
          target 'SampleProject' do
            pod 'RestKit', :git => 'https://github.com/RestKit/RestKit.git'
            pod 'RestKit', '~> 0.23.0'
          end
        end
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        e = should.raise(Informative) { analyzer.analyze }

        e.message.should.match /different sources for `RestKit`/
        e.message.should.match %r{RestKit \(from `https://github.com/RestKit/RestKit.git`\)}
        e.message.should.match /RestKit \(~> 0.23.0\)/
      end
    end

    describe 'podfile validation' do
      before do
        @sandbox = stub('Sandbox')
        @podfile = Podfile.new
        @analyzer = Installer::Analyzer.new(@sandbox, @podfile)
      end

      it 'raises when validating errors' do
        Installer::PodfileValidator.any_instance.expects(:validate)
        Installer::PodfileValidator.any_instance.expects(:valid?).returns(false)
        Installer::PodfileValidator.any_instance.stubs(:errors).returns(['ERROR'])

        should.raise(Informative) { @analyzer.send(:validate_podfile!) }.
          message.should.match /ERROR/
      end

      it 'warns when validating has warnings' do
        Installer::PodfileValidator.any_instance.expects(:validate)
        Installer::PodfileValidator.any_instance.expects(:valid?).returns(true)
        Installer::PodfileValidator.any_instance.stubs(:warnings).returns(['The Podfile does not contain any dependencies.'])

        @analyzer.send(:validate_podfile!)
        UI.warnings.should == "The Podfile does not contain any dependencies.\n"
      end
    end

    describe 'swift version' do
      before do
        @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
        @podfile = Podfile.new
        @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
      end

      it 'returns the swift version with the given requirements from the target definition' do
        target_definition = fixture_target_definition('App')
        target_definition.store_swift_version_requirements('>= 4.0')
        @banana_spec.swift_versions = ['3.0', '4.0']
        @analyzer.send(:determine_swift_version, @banana_spec, [target_definition]).should == '4.0'
      end

      it 'returns the swift version with the given requirements from all target definitions' do
        target_definition_one = fixture_target_definition('App1')
        target_definition_one.store_swift_version_requirements('>= 4.0')
        target_definition_two = fixture_target_definition('App2')
        target_definition_two.store_swift_version_requirements('= 4.2')
        @banana_spec.swift_versions = ['3.0', '4.0', '4.2']
        @analyzer.send(:determine_swift_version, @banana_spec, [target_definition_one, target_definition_two]).should == '4.2'
      end

      it 'returns an empty swift version if none of the requirements match' do
        target_definition_one = fixture_target_definition('App1')
        target_definition_one.store_swift_version_requirements('>= 4.0')
        target_definition_two = fixture_target_definition('App2')
        target_definition_two.store_swift_version_requirements('= 4.2')
        @banana_spec.swift_versions = ['3.0', '4.0']
        @analyzer.send(:determine_swift_version, @banana_spec, [target_definition_one, target_definition_two]).should == ''
      end

      it 'uses the swift version defined in the specification' do
        @banana_spec.swift_versions = ['3.0']
        target_definition = fixture_target_definition('App1')
        target_definition.swift_version = '2.3'
        @analyzer.send(:determine_swift_version, @banana_spec, [target_definition]).should == '3.0'
      end

      it 'uses the max swift version defined in the specification' do
        @banana_spec.swift_versions = ['3.0', '4.0']
        target_definition = fixture_target_definition('App1')
        target_definition.swift_version = '2.3'
        @analyzer.send(:determine_swift_version, @banana_spec, [target_definition]).should == '4.0'
      end

      it 'uses the swift version defined by the target definitions if no swift version is specified in the spec' do
        @banana_spec.swift_versions = []
        target_definition = fixture_target_definition('App1')
        target_definition.swift_version = '2.3'
        @analyzer.send(:determine_swift_version, @banana_spec, [target_definition]).should == '2.3'
      end
    end

    describe 'using lockfile checkout options' do
      before do
        @podfile = Pod::Podfile.new do
          target 'SampleProject' do
            pod 'BananaLib', :git => 'example.com'
          end
        end
        @dependency = @podfile.dependencies.first

        @lockfile_checkout_options = { :git => 'example.com', :commit => 'commit' }
        hash = {}
        hash['PODS'] = ['BananaLib (1.0.0)']
        hash['CHECKOUT OPTIONS'] = { 'BananaLib' => @lockfile_checkout_options }
        hash['SPEC CHECKSUMS'] = {}
        hash['COCOAPODS'] = Pod::VERSION
        @lockfile = Pod::Lockfile.new(hash)

        @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, @lockfile)
      end

      it 'returns that an update is required when there is no sandbox manifest' do
        @analyzer.sandbox.stubs(:manifest).returns(nil)
        @analyzer.should.send(:checkout_requires_update?, @dependency)
      end

      before do
        @sandbox_manifest = Pod::Lockfile.new(@lockfile.internal_data.deep_dup)
        @analyzer.sandbox.stubs(:manifest).returns(@sandbox_manifest)
        @analyzer.sandbox.stubs(:specification).with('BananaLib').returns(stub)
        @analyzer.sandbox.stubs(:specification_path).with('BananaLib').returns(stub)
        pod_dir = stub
        pod_dir.stubs(:directory?).returns(true)
        @analyzer.sandbox.stubs(:pod_dir).with('BananaLib').returns(pod_dir)
      end

      it 'returns whether or not an update is required' do
        @analyzer.send(:checkout_requires_update?, @dependency).should == false
        @sandbox_manifest.send(:checkout_options_data).delete('BananaLib')
        @analyzer.send(:checkout_requires_update?, @dependency).should == true
      end

      it 'uses lockfile checkout options when no source exists in the sandbox' do
        @sandbox_manifest.send(:checkout_options_data).delete('BananaLib')

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@lockfile_checkout_options, @dependency, @podfile.defined_in_file,
                                                 true).returns(downloader)

        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.unchanged << 'BananaLib'

        downloader.expects(:fetch)
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      it 'uses lockfile checkout options when a different checkout exists in the sandbox' do
        @sandbox_manifest.send(:checkout_options_data)['BananaLib'] = @lockfile_checkout_options.merge(:commit => 'other commit')

        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.unchanged << 'BananaLib'

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@lockfile_checkout_options, @dependency, @podfile.defined_in_file,
                                                 true).returns(downloader)

        downloader.expects(:fetch)
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      it 'ignores lockfile checkout options when the podfile state has changed' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.changed << 'BananaLib'

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@dependency.external_source, @dependency, @podfile.defined_in_file,
                                                 true).returns(downloader)

        downloader.expects(:fetch)
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      it 'ignores lockfile checkout options when updating selected pods' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.unchanged << 'BananaLib'

        @analyzer.stubs(:pods_to_update).returns(:pods => %w(BananaLib))

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@dependency.external_source, @dependency, @podfile.defined_in_file,
                                                 true).returns(downloader)

        downloader.expects(:fetch)
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      it 'ignores lockfile checkout options when updating all pods' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.unchanged << 'BananaLib'

        @analyzer.stubs(:pods_to_update).returns(true)

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@dependency.external_source, @dependency, @podfile.defined_in_file,
                                                 true).returns(downloader)

        downloader.expects(:fetch)
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      it 'does not use the cache when the podfile instructs not to clean' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.unchanged << 'BananaLib'

        @sandbox_manifest.send(:checkout_options_data).delete('BananaLib')

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@lockfile_checkout_options, @dependency, @podfile.defined_in_file,
                                                 false).returns(downloader)

        downloader.expects(:fetch)
        @analyzer.installation_options.clean = false
        @analyzer.send(:fetch_external_sources, podfile_state)
      end

      it 'does not re-fetch the external source when the sandbox has the correct revision of the source' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.unchanged << 'BananaLib'

        @analyzer.expects(:fetch_external_source).never
        @analyzer.send(:fetch_external_sources, podfile_state)
      end
    end
  end
end
