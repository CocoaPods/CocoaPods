require File.expand_path('../../../../spec_helper', __FILE__)
require 'cocoapods/installer/project_cache/target_cache_key.rb'

module Pod
  class Installer
    module ProjectCache
      describe ProjectCacheAnalyzer do
        before do
          @sandbox = config.sandbox
          @project_object_version = 1
          @build_configurations = { 'Debug' => :debug }
          @banana_lib = fixture_pod_target('banana-lib/BananaLib.podspec')
          @orange_lib = fixture_pod_target('orange-framework/OrangeFramework.podspec')
          @monkey_lib = fixture_pod_target('monkey/monkey.podspec')
          @pod_targets = [@banana_lib, @orange_lib, @monkey_lib]
          @main_aggregate_target = fixture_aggregate_target(@pod_targets)
          secondary_target_definition = fixture_target_definition('Pods2')
          @secondary_aggregate_target = fixture_aggregate_target([@banana_lib, @monkey_lib], BuildType.static_library,
                                                                 Pod::Target::DEFAULT_BUILD_CONFIGURATIONS, [],
                                                                 Pod::Platform.new(:ios, '6.0'),
                                                                 secondary_target_definition)
          @sandbox.project_path.mkpath
          @main_aggregate_target.support_files_dir.mkpath
          @secondary_aggregate_target.support_files_dir.mkpath
          @pod_targets.each do |target|
            @sandbox.pod_target_project_path(target.pod_name).mkpath
            target.support_files_dir.mkpath
          end
        end

        describe 'in general' do
          it 'returns all pod targets if there is no cache' do
            empty_cache = ProjectInstallationCache.new
            analyzer = ProjectCacheAnalyzer.new(@sandbox, empty_cache, @build_configurations, @project_object_version, {},
                                                @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns an empty result if no targets have changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal(nil)
          end

          it 'returns the list of pod targets that have changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            @banana_lib.root_spec.stubs(:checksum).returns('Blah')
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([@banana_lib])
            result.aggregate_targets_to_generate.should.equal(nil)
          end

          it 'returns all pod targets and aggregate targets if the build configurations have changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations.merge('Production' => :release), @project_object_version, {}, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns all pod targets and aggregate targets if the list of podfile plugins changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version, {})
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, { 'my-plugins' => {} }, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns empty list when comparing plugins with different ordering of arguments' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version, 'my-plugins' => %w[B A])
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, { 'my-plugins' => %w[A B] }, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal(nil)
          end

          it 'returns all pod targets and aggregate targets if the list of podfile plugins params changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version, 'my-plugins-1' => {}, 'my-plugins-2' => {})
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, { 'my-plugins-2' => { 'input' => 1 }, 'my-plugins-1' => {} }, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns empty list if the list of podfile plugins is not different' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version, 'my-plugins-1' => {}, 'my-plugins-2' => {})
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, { 'my-plugins-2' => {}, 'my-plugins-1' => {} }, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal(nil)
          end

          it 'returns all pod targets and aggregate targets if the project object version configurations has changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, 2, {}, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns all pod targets and aggregate targets if a project name has changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            @banana_lib.stubs(:project_name).returns('SomeProject')
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(@pod_targets)
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns all aggregate targets if one has changed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = {
              @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target),
              @secondary_aggregate_target.label => TargetCacheKey.from_cache_hash(@sandbox, 'BUILD_SETTINGS_CHECKSUM' => 'Blah'),
            }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)

            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [@main_aggregate_target, @secondary_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target, @secondary_aggregate_target])
          end

          it 'returns all aggregate targets if one has been removed' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = {
              @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target),
              @secondary_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @secondary_aggregate_target),
            }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)

            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target])
          end

          it 'returns all aggregate targets if one has been added' do
            cache_key_by_pod_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = {}
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)

            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, [], [@main_aggregate_target, @secondary_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([@main_aggregate_target, @secondary_aggregate_target])
          end

          it 'returns an empty list of aggregate targets when podfile has no targets and empty cache' do
            cache = ProjectInstallationCache.new
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, [], [])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([])
            result.aggregate_targets_to_generate.should.equal([])
          end

          it 'returns a pod if its target support dir is dirty' do
            FileUtils.rm_rf @orange_lib.support_files_dir
            cache_key_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([@orange_lib])
            result.aggregate_targets_to_generate.should.be.nil
          end

          it 'returns a pod if its project file is dirty' do
            FileUtils.rm_rf @sandbox.pod_target_project_path(@orange_lib.pod_name)
            cache_key_target_labels = Hash[@pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([@orange_lib])
            result.aggregate_targets_to_generate.should.be.nil
          end

          it 'returns the correct set of pod targets when adding a new one' do
            cache_pod_targets = [@banana_lib, @orange_lib]
            FileUtils.rm_rf @sandbox.pod_target_project_path(@monkey_lib.pod_name)

            cache_key_by_pod_target_labels = Hash[cache_pod_targets.map { |pod_target| [pod_target.label, TargetCacheKey.from_pod_target(@sandbox, pod_target)] }]
            cache_key_by_aggregate_target_labels = { @main_aggregate_target.label => TargetCacheKey.from_aggregate_target(@sandbox, @main_aggregate_target) }
            cache_key_target_labels = cache_key_by_pod_target_labels.merge(cache_key_by_aggregate_target_labels)
            cache = ProjectInstallationCache.new(cache_key_target_labels, @build_configurations, @project_object_version)

            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, @pod_targets, [@main_aggregate_target])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal([@monkey_lib])
            result.aggregate_targets_to_generate.should.equal(nil)
          end

          it 'returns all pod targets that share the same #pod_name' do
            subspec_target_1 = fixture_pod_target('matryoshka/matryoshka.podspec', BuildType.static_library, {}, [],
                                                  Pod::Platform.new(:ios, '6.0'), [], 'Foo')
            subspec_target_2 = fixture_pod_target('matryoshka/matryoshka.podspec', BuildType.static_library, {}, [],
                                                  Pod::Platform.new(:ios, '6.0'), [], 'Bar')
            subspec_pods = [subspec_target_2, subspec_target_1]
            subspec_pods.each do |target|
              @sandbox.pod_target_project_path(target.pod_name).mkpath
              target.support_files_dir.mkpath
            end

            cache_key_by_aggregate_target_labels = {
              subspec_target_1.label => TargetCacheKey.from_pod_target(@sandbox, subspec_target_1),
              subspec_target_2.label => TargetCacheKey.from_cache_hash(@sandbox, 'BUILD_SETTINGS_CHECKSUM' => 'Blah'),
            }
            cache = ProjectInstallationCache.new(cache_key_by_aggregate_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, subspec_pods, [])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(subspec_pods)
            result.aggregate_targets_to_generate.should.equal([])
          end

          it 'returns sibling pod target when adding a new subspec' do
            original_subspec = fixture_pod_target('matryoshka/matryoshka.podspec', BuildType.static_library, {}, [],
                                                  Pod::Platform.new(:ios, '6.0'), [])
            subspec_target_1 = fixture_pod_target('matryoshka/matryoshka.podspec', BuildType.static_library, {}, [],
                                                  Pod::Platform.new(:ios, '6.0'), [], 'Foo')
            subspec_target_2 = fixture_pod_target('matryoshka/matryoshka.podspec', BuildType.static_library, {}, [],
                                                  Pod::Platform.new(:ios, '6.0'), [], 'Bar')
            subspec_pods = [subspec_target_2, subspec_target_1]
            subspec_pods.each do |target|
              @sandbox.pod_target_project_path(target.pod_name).mkpath
              target.support_files_dir.mkpath
            end

            cache_key_by_aggregate_target_labels = {
              subspec_target_1.label => TargetCacheKey.from_pod_target(@sandbox, original_subspec),
            }

            cache = ProjectInstallationCache.new(cache_key_by_aggregate_target_labels, @build_configurations, @project_object_version)
            analyzer = ProjectCacheAnalyzer.new(@sandbox, cache, @build_configurations, @project_object_version, {}, subspec_pods, [])
            result = analyzer.analyze
            result.pod_targets_to_generate.should.equal(subspec_pods)
            result.aggregate_targets_to_generate.should.equal(nil)
          end
        end
      end
    end
  end
end
