require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Installer::Analyzer do
    describe 'Analysis' do
      before do
        repos = [Source.new(fixture('spec-repos/test_repo')), MasterSource.new(fixture('spec-repos/master'))]
        aggregate = Pod::Source::Aggregate.new(repos)
        config.sources_manager.stubs(:aggregate).returns(aggregate)
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
        @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, @lockfile)
      end

      it 'returns whether an installation should be performed' do
        @analyzer.needs_install?.should.be.true
      end

      it 'returns whether the Podfile has changes' do
        analysis_result = @analyzer.analyze(false)
        @analyzer.podfile_needs_install?(analysis_result).should.be.true
      end

      it 'returns whether the sandbox is not in sync with the lockfile' do
        analysis_result = @analyzer.analyze(false)
        @analyzer.sandbox_needs_install?(analysis_result).should.be.true
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
        @analyzer.stubs(:sources).returns(config.sources_manager.master)
        config.sources_manager.expects(:update).once.with('master')
        @analyzer.update_repositories
      end

      it 'does not update sources if there are no dependencies' do
        podfile = Podfile.new do
          source 'https://github.com/CocoaPods/Specs.git'
          # No dependencies specified
        end
        config.verbose = true

        config.sources_manager.expects(:update).never
        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        analyzer.update_repositories
      end

      it 'does not update non-git repositories' do
        tmp_directory = Pathname(Dir.tmpdir) + 'CocoaPods'
        FileUtils.mkdir_p(tmp_directory)
        FileUtils.cp_r(ROOT + 'spec/fixtures/spec-repos/test_repo/', tmp_directory)
        non_git_repo = tmp_directory + 'test_repo'

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

        UI.output.should.match /Skipping `#{source.name}` update because the repository is not a git source repository./

        FileUtils.rm_rf(non_git_repo)
      end

      it 'updates sources specified with dependencies' do
        repo_url = 'https://url/to/specs.git'
        podfile = Podfile.new do
          source 'repo_1'
          pod 'BananaLib', '1.0', :source => repo_url
          pod 'JSONKit', :source => repo_url
        end
        config.verbose = true

        # Note that we are explicitly ignoring 'repo_1' since it isn't used.
        source = mock
        source.stubs(:name).returns('repo_2')
        source.stubs(:repo).returns('/repo/cache/path')
        config.sources_manager.expects(:find_or_create_source_with_url).with(repo_url).returns(source)
        source.stubs(:git?).returns(true)
        config.sources_manager.expects(:update).once.with(source.name)

        analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile, nil)
        analyzer.update_repositories
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
          restkit_target.dependent_targets.all?(&:scoped).should.be.true
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
          @analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile, nil)
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
          result = analyzer.analyze

          pod_targets = result.targets.flat_map(&:pod_targets).uniq
          Hash[pod_targets.map { |t| [t.label, t.target_definitions.map(&:label).sort] }.sort].should == {
            'BananaLib'  => %w(Pods-SampleProject Pods-SampleProject-TestRunner),
            'monkey-iOS' => %w(Pods-SampleProject Pods-SampleProject-TestRunner),
            'monkey-OSX' => %w(Pods-CLITool),
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
      end

      describe 'no-integrate platform validation' do
        before do
          repos = [Source.new(fixture('spec-repos/test_repo'))]
          aggregate = Pod::Source::Aggregate.new(repos)
          config.sources_manager.stubs(:aggregate).returns(aggregate)
          aggregate.sources.first.stubs(:url).returns(SpecHelper.test_repo_url)
        end

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
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:payload).map(&:to_s).
          should == ['JSONKit (= 1.5pre)', 'SVPullToRefresh (= 0.4)']
      end

      it 'does not lock the dependencies in update mode' do
        @analyzer.update = true
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).to_a.map(&:payload).should == []
      end

      it 'unlocks dependencies in a case-insensitive manner' do
        @analyzer.update = { :pods => %w(JSONKit) }
        @analyzer.analyze
        @analyzer.send(:locked_dependencies).map(&:payload).map(&:to_s).
          should == ['SVPullToRefresh (= 0.4)']
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
        analyzer = Installer::Analyzer.new(config.sandbox, podfile, lockfile)

        analyzer.update = { :pods => %w(AFNetworking) }
        analyzer.analyze.specifications.
          find { |s| s.name == 'AFNetworking' }.
          version.to_s.should == '2.4.1'
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

      #--------------------------------------#

      it 'fetches the dependencies with external sources' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.added << 'BananaLib'
        @analyzer.stubs(:result).returns(stub(:podfile_state => podfile_state))
        @podfile.stubs(:dependencies).returns([Dependency.new('BananaLib', :git => 'example.com')])
        ExternalSources::DownloaderSource.any_instance.expects(:fetch)
        @analyzer.send(:fetch_external_sources)
      end

      it 'does not download the same source multiple times for different subspecs' do
        podfile_state = Installer::Analyzer::SpecsState.new
        podfile_state.added << 'ARAnalytics'
        @analyzer.stubs(:result).returns(stub(:podfile_state => podfile_state))
        @podfile.stubs(:dependencies).returns([
          Dependency.new('ARAnalytics/Mixpanel', :git => 'https://github.com/orta/ARAnalytics', :commit => '6f1a1c314894437e7e5c09572c276e644dbfb64b'),
          Dependency.new('ARAnalytics/HockeyApp', :git => 'https://github.com/orta/ARAnalytics', :commit => '6f1a1c314894437e7e5c09572c276e644dbfb64b'),
        ])
        ExternalSources::DownloaderSource.any_instance.expects(:fetch).once
        @analyzer.send(:fetch_external_sources)
      end

      xit 'it fetches the specification from either the sandbox or from the remote by default' do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        ExternalSources::DownloaderSource.any_instance.expects(:specification_from_external).returns(Specification.new).once
        @resolver.send(:set_from_external_source, dependency)
      end

      xit 'it fetches the specification from the remote if in update mode' do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        ExternalSources::DownloaderSource.any_instance.expects(:specification).returns(Specification.new).once
        @resolver.update_external_specs = false
        @resolver.send(:set_from_external_source, dependency)
      end

      xit 'it fetches the specification only from the sandbox if pre-downloads are disabled' do
        dependency = Dependency.new('Name', :git => 'www.example.com')
        Sandbox.any_instance.expects(:specification).returns(Specification.new).once
        @resolver.allow_pre_downloads = true
        @resolver.send(:set_from_external_source, dependency)
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
          source 'https://github.com/CocoaPods/Specs.git'
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

      describe 'extension targets' do
        before do
          SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project')
          @podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '6.0'
            project 'Sample Extensions Project/Sample Extensions Project'

            target 'Sample Extensions Project' do
              pod 'JSONKit', '1.4'
            end

            target 'Today Extension' do
              pod 'monkey'
            end
          end
        end

        it 'copies extension pod targets to host target, when use_frameworks!' do
          @podfile.use_frameworks!
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
          result = analyzer.analyze

          result.targets.flat_map { |at| at.pod_targets.map { |pt| "#{at.name}/#{pt.name}" } }.sort.should == [
            'Pods-Sample Extensions Project/JSONKit',
            'Pods-Sample Extensions Project/monkey',
            'Pods-Today Extension/monkey',
          ].sort
        end

        it 'does not copy extension pod targets to host target, when not use_frameworks!' do
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, @podfile)
          result = analyzer.analyze

          result.targets.flat_map { |at| at.pod_targets.map { |pt| "#{at.name}/#{pt.name}" } }.sort.should == [
            'Pods-Sample Extensions Project/JSONKit',
            'Pods-Today Extension/monkey',
          ].sort
        end

        it "raises when unable to find an extension's host target" do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            use_frameworks!
            platform :ios, '6.0'
            project 'Sample Extensions Project/Sample Extensions Project'

            target 'Today Extension' do
              pod 'monkey'
            end
          end
          analyzer = Pod::Installer::Analyzer.new(config.sandbox, podfile)
          should.raise Informative do
            analyzer.analyze
          end.message.should.match /Unable to find host target for Pods-Today Extension. Please add the host targets for the extensions to the Podfile/
        end

        it 'raises when the extension calls use_frameworks!, but the host target does not' do
          podfile = Pod::Podfile.new do
            source SpecHelper.test_repo_url
            platform :ios, '6.0'
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
          end.message.should.match /Pods-Sample Extensions Project must call use_frameworks! because it is hosting an extension that calls use_frameworks!/
        end
      end

      #-------------------------------------------------------------------------#

      describe 'Private helpers' do
        describe '#sources' do
          describe 'when there are no explicit sources' do
            it 'defaults to the master spec repository' do
              @analyzer.send(:sources).map(&:url).should ==
                ['https://github.com/CocoaPods/Specs.git']
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
              config.sources_manager.expects(:find_or_create_source_with_url).once
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
          source 'https://github.com/CocoaPods/Specs.git'
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
          source 'https://github.com/CocoaPods/Specs.git'
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
          source 'https://github.com/CocoaPods/Specs.git'
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
        @podfile = stub('Podfile')
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
        @analyzer.sandbox.manifest = @sandbox_manifest
        @analyzer.sandbox.stubs(:specification).with('BananaLib').returns(stub)
        pod_dir = stub
        pod_dir.stubs(:directory?).returns(true)
        @analyzer.sandbox.stubs(:pod_dir).with('BananaLib').returns(pod_dir)
      end

      it 'returns whether or not an update is required' do
        @analyzer.send(:checkout_requires_update?, @dependency).should == false
        @sandbox_manifest.send(:checkout_options_data).delete('BananaLib')
        @analyzer.send(:checkout_requires_update?, @dependency).should == true
      end

      before do
        @analyzer.result = Installer::Analyzer::AnalysisResult.new
        @analyzer.result.podfile_state = Installer::Analyzer::SpecsState.new
      end

      it 'uses lockfile checkout options when no source exists in the sandbox' do
        @analyzer.result.podfile_state.unchanged << 'BananaLib'
        @sandbox_manifest.send(:checkout_options_data).delete('BananaLib')

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@lockfile_checkout_options, @dependency, @podfile.defined_in_file).returns(downloader)

        downloader.expects(:fetch)
        downloader.expects(:can_cache=).with(true).once
        @analyzer.send(:fetch_external_sources)
      end

      it 'uses lockfile checkout options when a different checkout exists in the sandbox' do
        @analyzer.result.podfile_state.unchanged << 'BananaLib'
        @sandbox_manifest.send(:checkout_options_data)['BananaLib'] = @lockfile_checkout_options.merge(:commit => 'other commit')

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@lockfile_checkout_options, @dependency, @podfile.defined_in_file).returns(downloader)

        downloader.expects(:fetch)
        downloader.expects(:can_cache=).with(true).once
        @analyzer.send(:fetch_external_sources)
      end

      it 'ignores lockfile checkout options when the podfile state has changed' do
        @analyzer.result.podfile_state.changed << 'BananaLib'

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@dependency.external_source, @dependency, @podfile.defined_in_file).returns(downloader)

        downloader.expects(:fetch)
        downloader.expects(:can_cache=).with(true).once
        @analyzer.send(:fetch_external_sources)
      end

      it 'ignores lockfile checkout options when updating selected pods' do
        @analyzer.result.podfile_state.unchanged << 'BananaLib'
        @analyzer.stubs(:update).returns(:pods => %w(BananaLib))

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@dependency.external_source, @dependency, @podfile.defined_in_file).returns(downloader)

        downloader.expects(:fetch)
        downloader.expects(:can_cache=).with(true).once
        @analyzer.send(:fetch_external_sources)
      end

      it 'ignores lockfile checkout options when updating all pods' do
        @analyzer.result.podfile_state.unchanged << 'BananaLib'
        @analyzer.stubs(:update).returns(true)

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@dependency.external_source, @dependency, @podfile.defined_in_file).returns(downloader)

        downloader.expects(:fetch)
        downloader.expects(:can_cache=).with(true).once
        @analyzer.send(:fetch_external_sources)
      end

      it 'does not use the cache when the podfile instructs not to clean' do
        @analyzer.result.podfile_state.unchanged << 'BananaLib'
        @sandbox_manifest.send(:checkout_options_data).delete('BananaLib')

        downloader = stub('DownloaderSource')
        ExternalSources.stubs(:from_params).with(@lockfile_checkout_options, @dependency, @podfile.defined_in_file).returns(downloader)

        downloader.expects(:fetch)
        downloader.expects(:can_cache=).with(false).once
        @analyzer.installation_options.clean = false
        @analyzer.send(:fetch_external_sources)
      end

      it 'does not re-fetch the external source when the sandbox has the correct revision of the source' do
        @analyzer.result.podfile_state.unchanged << 'BananaLib'

        @analyzer.expects(:fetch_external_source).never
        @analyzer.send(:fetch_external_sources)
      end
    end
  end
end
