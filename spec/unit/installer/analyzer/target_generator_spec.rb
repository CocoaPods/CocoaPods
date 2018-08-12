require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Analyzer
      describe TargetGenerator do
        before do
          @sandbox = stub('Sandbox')
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
          @podfile_dependency_cache = Installer::Analyzer::PodfileDependencyCache.from_podfile(@podfile)
          SpecHelper.create_sample_app_copy_from_fixture('SampleProject')
        end

        describe '#requires_64_bit_archs' do
          it 'correctly determines when a platform requires 64-bit architectures' do
            TargetGenerator.send(:requires_64_bit_archs?, Platform.new(:ios, '11.0')).should.be.true
            TargetGenerator.send(:requires_64_bit_archs?, Platform.new(:ios, '10.0')).should.be.false
            TargetGenerator.send(:requires_64_bit_archs?, Platform.new(:osx)).should.be.true
            TargetGenerator.send(:requires_64_bit_archs?, Platform.new(:tvos)).should.be.false
            TargetGenerator.send(:requires_64_bit_archs?, Platform.new(:watchos)).should.be.false
          end
        end

        describe '#filter_pod_targets_for_target_definition' do
          it 'does include pod target if any spec is not used by tests only and is part of target definition' do
            spec1 = Resolver::ResolverSpecification.new(stub, false, nil)
            spec2 = Resolver::ResolverSpecification.new(stub, true, nil)
            target_definition = @podfile.target_definitions['SampleProject']
            pod_target = stub(:name => 'Pod1', :target_definitions => [target_definition], :specs => [spec1.spec, spec2.spec], :pod_name => 'Pod1')
            resolver_specs = [spec1, spec2]
            TargetGenerator.send(:filter_pod_targets_for_target_definition,
                                 target_definition,
                                 [pod_target],
                                 resolver_specs,
                                 @podfile_dependency_cache,
                                 %w(Release)).should == { 'Release' => [pod_target] }
          end

          it 'does not include pod target if its used by tests only' do
            spec1 = Resolver::ResolverSpecification.new(stub, true, nil)
            spec2 = Resolver::ResolverSpecification.new(stub, true, nil)
            target_definition = stub('TargetDefinition')
            pod_target = stub(:name => 'Pod1', :target_definitions => [target_definition], :specs => [spec1.spec, spec2.spec])
            resolver_specs = [spec1, spec2]
            TargetGenerator.send(:filter_pod_targets_for_target_definition,
                                 target_definition,
                                 [pod_target],
                                 resolver_specs,
                                 @podfile_dependency_cache,
                                 %w(Release)).should == { 'Release' => [] }
          end

          it 'does not include pod target if its not part of the target definition' do
            spec = Resolver::ResolverSpecification.new(stub, false, nil)
            target_definition = stub('TargetDefinition')
            pod_target = stub(:name => 'Pod1', :target_definitions => [], :specs => [spec.spec])
            resolver_specs = [spec]
            TargetGenerator.send(:filter_pod_targets_for_target_definition,
                                 target_definition,
                                 [pod_target],
                                 resolver_specs,
                                 @podfile_dependency_cache,
                                 %w(Release)).should == { 'Release' => [] }
          end
        end
      end
    end
  end
end
