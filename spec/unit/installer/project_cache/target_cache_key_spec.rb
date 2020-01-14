require File.expand_path('../../../../spec_helper', __FILE__)
require 'cocoapods/installer/project_cache/target_cache_key.rb'

module Pod
  class Installer
    module ProjectCache
      describe TargetCacheKey do
        before do
          @banana_spec = fixture_spec('banana-lib/BananaLib.podspec')
          @banana_pod_target = fixture_pod_target(@banana_spec)
          @banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target)
          @aggregate_target = fixture_aggregate_target
          @aggregate_target_cache_key = TargetCacheKey.from_aggregate_target(config.sandbox, @aggregate_target)
        end

        describe 'cache key structure' do
          it 'should order subspecs alphabetically' do
            root_spec = fixture_spec('banana-lib/BananaLib.podspec')
            subspec1 = Pod::Specification.new(root_spec, 'MUS')
            subspec2 = Pod::Specification.new(root_spec, 'Module')

            pod_target = fixture_pod_target_with_specs([root_spec, subspec1, subspec2], BuildType.dynamic_framework)
            cache_key = TargetCacheKey.from_pod_target(config.sandbox, pod_target)
            cache_key.to_h['SPECS'].should.equal(['BananaLib (1.0)', 'BananaLib/Module (1.0)', 'BananaLib/MUS (1.0)'])
          end

          it 'should output files for aggregate target if it has aggregate resources' do
            aggregate_target = AggregateTarget.new(config.sandbox, BuildType.static_library, { 'Debug' => :debug }, [], Platform.ios,
                                                   fixture_target_definition('MyApp'), config.sandbox.root.dirname, nil,
                                                   nil, 'Debug' => [@banana_pod_target])
            aggregate_target_cache_key = TargetCacheKey.from_aggregate_target(config.sandbox, aggregate_target)
            library_resources = @banana_pod_target.resource_paths.values.flatten.sort_by(&:downcase)
            aggregate_target_cache_key.to_h['FILES'].should.equal(library_resources)
          end
        end

        describe 'key_difference with pod targets' do
          it 'should return equality for the same pod targets' do
            @banana_cache_key.key_difference(@banana_cache_key).should.equal(:none)
          end

          it 'should return inequality for different checksums' do
            diff_banana_checksum = fixture_pod_target('banana-lib/BananaLib.podspec')
            diff_banana_checksum.root_spec.stubs(:checksum).returns('blah')
            diff_banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, diff_banana_checksum)
            difference = @banana_cache_key.key_difference(diff_banana_cache_key)
            inverse_difference = diff_banana_cache_key.key_difference(@banana_cache_key)
            difference.should.equal(:project)
            inverse_difference.should.equal(:project)
          end

          it 'should return inequality for external pod turned local' do
            local_banana = fixture_pod_target('banana-lib/BananaLib.podspec')
            local_banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, local_banana, :is_local_pod => true)
            difference = @banana_cache_key.key_difference(local_banana_cache_key)
            inverse_difference = local_banana_cache_key.key_difference(@banana_cache_key)
            difference.should.equal(:project)
            inverse_difference.should.equal(:project)
          end

          it 'should return inequality for aggregate vs local pods' do
            difference = @banana_cache_key.key_difference(@aggregate_target_cache_key)
            inverse_difference = @aggregate_target_cache_key.key_difference(@banana_cache_key)
            difference.should.equal(:project)
            inverse_difference.should.equal(:project)
          end

          it 'should return equality for two aggregate targets' do
            @aggregate_target_cache_key.key_difference(@aggregate_target_cache_key).should.equal(:none)
          end

          it 'should return inequality by adding a dependency' do
            added_dependency_aggregate_target = AggregateTarget.new(config.sandbox, BuildType.static_library, { 'Debug' => :debug }, [], Platform.ios,
                                                                    fixture_target_definition('MyApp'), config.sandbox.root.dirname, nil,
                                                                    nil, 'Debug' => [@banana_pod_target])
            added_dependency_cache_key = TargetCacheKey.from_aggregate_target(config.sandbox,
                                                                              added_dependency_aggregate_target)
            diff = @aggregate_target_cache_key.key_difference(added_dependency_cache_key)
            inverse_diff = added_dependency_cache_key.key_difference(@aggregate_target_cache_key)
            diff.should.equal(:project)
            inverse_diff.should.equal(:project)
          end

          it 'should return inequality when checkout sha changes' do
            old_checkout_options = { 'BananaLib' => { :git => 'https://git.com', :sha => '1' } }
            new_checkout_options = { 'BananaLib' => { :git => 'https://git.com', :sha => '2' } }

            banana_sha1_cache_key = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target,
                                                                   :checkout_options => old_checkout_options)
            banana_sha2_cache_key = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target,
                                                                   :checkout_options => new_checkout_options)

            banana_sha1_cache_key.key_difference(banana_sha2_cache_key).should.equal(:project)

            banana_no_checkout_options = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target)
            banana_no_checkout_options.key_difference(banana_sha1_cache_key).should.equal(:project)
            banana_sha1_cache_key.key_difference(banana_no_checkout_options).should.equal(:project)
          end

          it 'should return inequality if the list of tracked files has changed' do
            added_banana_files_target = fixture_pod_target('banana-lib/BananaLib.podspec')
            @banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target,
                                                               :is_local_pod => true)
            new_file = [(Pod::Sandbox::PathList.new(@banana_spec.defined_in_file.dirname).root + 'CoolFile.h').to_s]
            added_files_list = new_file + @banana_pod_target.all_files
            added_banana_files_target.stubs(:all_files).returns(added_files_list)

            added_banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, added_banana_files_target,
                                                                    :is_local_pod => true)
            diff = added_banana_cache_key.key_difference(@banana_cache_key)
            inverse_diff = @banana_cache_key.key_difference(added_banana_cache_key)
            diff.should.equal(:project)
            inverse_diff.should.equal(:project)
          end

          it 'should return inequality for aggregate target if the list of tracked resource files has changed' do
            @aggregate_target = fixture_aggregate_target([@banana_pod_target])
            @aggregate_target_cache_key = TargetCacheKey.from_aggregate_target(config.sandbox, @aggregate_target)

            added_banana_files_target = fixture_pod_target('banana-lib/BananaLib.podspec')
            new_file = (Pod::Sandbox::PathList.new(@banana_spec.defined_in_file.dirname).root + 'Resources/CoolFile.png').to_s
            new_file = '${PODS_ROOT}/' + Pathname.new(new_file).relative_path_from(config.sandbox.root).to_s
            added_files_list = @banana_pod_target.resource_paths
            added_files_list['BananaLib'] << new_file
            added_banana_files_target.stubs(:resource_paths).returns(added_files_list)

            added_aggregate_target = fixture_aggregate_target([added_banana_files_target])
            added_aggregate_target_cache_key = TargetCacheKey.from_aggregate_target(config.sandbox, added_aggregate_target)
            added_aggregate_target_cache_key.to_h['FILES'].should.include?(new_file)
            diff = added_aggregate_target_cache_key.key_difference(@aggregate_target_cache_key)
            inverse_diff = @aggregate_target_cache_key.key_difference(added_aggregate_target_cache_key)
            diff.should.equal(:project)
            inverse_diff.should.equal(:project)
          end

          it 'should return inequality if the build settings change' do
            changed_build_settings_target = fixture_pod_target('banana-lib/BananaLib.podspec')
            changed_build_settings = {
              'CONFIGURATION_BUILD_DIR' => '${PODS_CONFIGURATION_BUILD_DIR}/BananaLib',
              'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/../../spec/fixtures/banana-lib"',
            }
            changed_build_settings_target.build_settings.each_value { |settings| settings.stubs(:xcconfig).returns(Xcodeproj::Config.new(changed_build_settings)) }
            changed_build_settings_cache_key = TargetCacheKey.from_pod_target(config.sandbox,
                                                                              changed_build_settings_target)
            @banana_cache_key.key_difference(changed_build_settings_cache_key).should.equal(:project)
            changed_build_settings_cache_key.key_difference(@banana_cache_key).should.equal(:project)
          end

          it 'should return inequality if the project name changed' do
            banana_project_target = fixture_pod_target('banana-lib/BananaLib.podspec')
            @banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target)
            banana_project_target.stubs(:project_name).returns('SomeProject')

            added_banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, banana_project_target)
            diff = added_banana_cache_key.key_difference(@banana_cache_key)
            inverse_diff = @banana_cache_key.key_difference(added_banana_cache_key)
            diff.should.equal(:project)
            inverse_diff.should.equal(:project)
          end
        end

        describe 'key_difference with hash objects' do
          it 'should return equality for same pod target and hash' do
            hash_cache_key = TargetCacheKey.from_cache_hash(config.sandbox, @banana_cache_key.to_h)
            @banana_cache_key.key_difference(hash_cache_key).should.equal(:none)
            hash_cache_key.key_difference(@banana_cache_key).should.equal(:none)
          end

          it 'should return equality for same local pod target and hash' do
            local_banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target,
                                                                    :is_local_pod => true)
            hash_cache_key = TargetCacheKey.from_cache_hash(config.sandbox, local_banana_cache_key.to_h)
            local_banana_cache_key.key_difference(hash_cache_key).should.equal(:none)
            hash_cache_key.key_difference(local_banana_cache_key).should.equal(:none)
          end

          it 'should return inequality for modified pod target' do
            local_banana_cache_key = TargetCacheKey.from_pod_target(config.sandbox, @banana_pod_target,
                                                                    :is_local_pod => true)
            cache_hash = local_banana_cache_key.to_h.dup
            cache_hash['FILES'] = cache_hash['FILES'].dup << 'Blah.h'
            hash_cache_key = TargetCacheKey.from_cache_hash(config.sandbox, cache_hash)
            local_banana_cache_key.key_difference(hash_cache_key).should.equal(:project)
            hash_cache_key.key_difference(local_banana_cache_key).should.equal(:project)
          end
        end
      end
    end
  end
end
