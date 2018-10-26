require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Target
    describe BuildSettings do
      def pod(pod_target)
        BuildSettings::PodTargetSettings.new(pod_target)
      end

      def aggregate(aggregate_target, configuration_name = 'Release')
        BuildSettings::AggregateTargetSettings.new(aggregate_target, configuration_name)
      end

      describe 'memoization' do
        it 'memoizes methods when requested' do
          cls = Class.new(BuildSettings) do
            define_build_settings_method :foobar, :memoized => true do
              Object.new
            end
          end

          settings = cls.new(stub('Target'))

          object = settings.foobar
          object.should.be.frozen
          object.should.equal?(settings.foobar)
        end

        it 'memoizes array methods when requested' do
          cls = Class.new(BuildSettings) do
            define_build_settings_method :foobar, :memoized => true, :sorted => true, :uniqued => true do
              %w(b a c a)
            end
          end

          settings = cls.new(stub('Target'))

          object = settings.foobar
          object.should.be.frozen
          object.should == %w(a b c)
          object.should.equal?(settings.foobar)
        end
      end

      #---------------------------------------------------------------------#

      describe '::add_developers_frameworks_if_needed' do
        it 'adds the developer frameworks search paths to the xcconfig if SenTestingKit has been detected' do
          xcconfig = BuildSettings.new(stub('Target'))
          xcconfig.stubs(:frameworks => %w(SenTestingKit))
          frameworks_search_paths = xcconfig.framework_search_paths
          frameworks_search_paths.should == %w($(PLATFORM_DIR)/Developer/Library/Frameworks)
        end

        it 'adds the developer frameworks search paths to the xcconfig if XCTest has been detected' do
          xcconfig = BuildSettings.new(stub('Target'))
          xcconfig.stubs(:frameworks => %w(XCTest))
          frameworks_search_paths = xcconfig.framework_search_paths
          frameworks_search_paths.should == %w($(PLATFORM_DIR)/Developer/Library/Frameworks)
        end
      end

      #---------------------------------------------------------------------#

      describe '::add_language_specific_settings' do
        it 'does not add OTHER_SWIFT_FLAGS to the xcconfig if the target does not use swift' do
          target = fixture_pod_target('integration/Reachability/Reachability.podspec')
          build_settings = pod(target)
          other_swift_flags = build_settings.xcconfig.to_hash['OTHER_SWIFT_FLAGS']
          other_swift_flags.should.be.nil
        end

        it 'does not add the -suppress-warnings flag to the xcconfig if the target uses swift, but does not inhibit warnings' do
          target = fixture_pod_target('integration/Reachability/Reachability.podspec')
          target.stubs(:uses_swift? => true, :inhibit_warnings? => false)
          build_settings = pod(target)
          other_swift_flags = build_settings.xcconfig.to_hash['OTHER_SWIFT_FLAGS']
          other_swift_flags.should.not.include '-suppress-warnings'
        end

        it 'adds the -suppress-warnings flag to the xcconfig if the target uses swift and inhibits warnings' do
          target = fixture_pod_target('integration/Reachability/Reachability.podspec')
          target.stubs(:uses_swift? => true, :inhibit_warnings? => true)
          build_settings = pod(target)
          other_swift_flags = build_settings.xcconfig.to_hash['OTHER_SWIFT_FLAGS']
          other_swift_flags.should.include '-suppress-warnings'
        end
      end

      #---------------------------------------------------------------------#

      describe 'concerning settings for file accessors' do
        it 'does not propagate framework or libraries from a test specification to an aggregate target' do
          target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new)
          spec = stub('spec', :library_specification? => false, :spec_type => :test)
          consumer = stub('consumer',
                          :libraries => ['xml2'],
                          :frameworks => ['XCTest'],
                          :weak_frameworks => [],
                          :spec => spec,
                         )
          file_accessor = stub('file_accessor',
                               :spec => spec,
                               :spec_consumer => consumer,
                               :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
                               :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
                               :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
                               :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
                              )
          pod_target = stub('pod_target',
                            :file_accessors => [file_accessor],
                            :requires_frameworks? => true,
                            :dependent_targets => [],
                            :recursive_dependent_targets => [],
                            :sandbox => config.sandbox,
                            :include_in_build_config? => true,
                            :should_build? => false,
                            :spec_consumers => [consumer],
                            :static_framework? => false,
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                           )
          pod_target.stubs(:build_settings => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target])
          aggregate(aggregate_target).other_ldflags.should.not.include '-framework'
        end

        it 'does not propagate framework or libraries from a app specification to an aggregate target' do
          target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new)
          spec = stub('spec', :library_specification? => false, :spec_type => :app)
          consumer = stub('consumer',
                          :libraries => ['xml2'],
                          :frameworks => ['XCTest'],
                          :weak_frameworks => [],
                          :spec => spec,
                         )
          file_accessor = stub('file_accessor',
                               :spec => spec,
                               :spec_consumer => consumer,
                               :vendored_static_frameworks => [config.sandbox.root + 'StaticFramework.framework'],
                               :vendored_static_libraries => [config.sandbox.root + 'StaticLibrary.a'],
                               :vendored_dynamic_frameworks => [config.sandbox.root + 'VendoredFramework.framework'],
                               :vendored_dynamic_libraries => [config.sandbox.root + 'VendoredDyld.dyld'],
                              )
          pod_target = stub('pod_target',
                            :file_accessors => [file_accessor],
                            :requires_frameworks? => true,
                            :dependent_targets => [],
                            :recursive_dependent_targets => [],
                            :sandbox => config.sandbox,
                            :include_in_build_config? => true,
                            :should_build? => false,
                            :spec_consumers => [consumer],
                            :static_framework? => false,
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                           )
          pod_target.stubs(:build_settings => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target])
          aggregate(aggregate_target).other_ldflags.should.not.include '-framework'
        end
      end

      describe 'concerning other_ld_flags' do
        it 'other_ld_flags should not include -ObjC when there are not static frameworks' do
          target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new)
          spec = stub('spec', :library_specification? => false, :spec_type => :test)
          consumer = stub('consumer',
                          :libraries => ['xml2'],
                          :frameworks => ['XCTest'],
                          :weak_frameworks => [],
                          :spec => spec,
                         )
          file_accessor = stub('file_accessor',
                               :spec => spec,
                               :spec_consumer => consumer,
                               :vendored_static_artifacts => [],
                              )
          pod_target = stub('pod_target',
                            :file_accessors => [file_accessor],
                            :requires_frameworks? => true,
                            :dependent_targets => [],
                            :recursive_dependent_targets => [],
                            :sandbox => config.sandbox,
                            :include_in_build_config? => true,
                            :should_build? => false,
                            :spec_consumers => [consumer],
                            :static_framework? => false,
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                           )
          pod_target.stubs(:build_settings => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target], true)
          aggregate(aggregate_target).other_ldflags.should.not.include '-ObjC'
        end

        it 'other_ld_flags should include -ObjC when linking static frameworks' do
          target_definition = stub('target_definition', :inheritance => 'complete', :abstract? => false, :podfile => Podfile.new)
          spec = stub('spec', :library_specification? => true, :spec_type => :library)
          consumer = stub('consumer',
                          :libraries => ['xml2'],
                          :frameworks => ['XCTest'],
                          :weak_frameworks => [],
                          :spec => spec,
                         )
          file_accessor = stub('file_accessor',
                               :spec => spec,
                               :spec_consumer => consumer,
                               :vendored_static_artifacts => [],
                               :vendored_static_libraries => [],
                               :vendored_dynamic_libraries => [],
                               :vendored_static_frameworks => [],
                               :vendored_dynamic_frameworks => [],
                              )
          pod_target = stub('pod_target',
                            :file_accessors => [file_accessor],
                            :requires_frameworks? => true,
                            :dependent_targets => [],
                            :recursive_dependent_targets => [],
                            :sandbox => config.sandbox,
                            :include_in_build_config? => true,
                            :should_build? => false,
                            :spec_consumers => [consumer],
                            :static_framework? => true,
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                           )
          pod_target.stubs(:build_settings => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target], true)
          aggregate(aggregate_target).other_ldflags.should.include '-ObjC'
        end
      end

      #---------------------------------------------------------------------#
    end
  end
end
