require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  class Target
    describe BuildSettings do
      def pod(pod_target)
        BuildSettings::PodTargetSettings.new(pod_target, nil, :configuration => :debug)
      end

      def aggregate(aggregate_target, configuration_name = 'Release')
        BuildSettings::AggregateTargetSettings.new(aggregate_target, configuration_name, :configuration => configuration_name.downcase.to_sym)
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

        it 'adds the developer frameworks search paths to the xcconfig if XCTest has been detected as a weak framework' do
          xcconfig = BuildSettings.new(stub('Target'))
          xcconfig.stubs(:weak_frameworks => %w(XCTest))
          frameworks_search_paths = xcconfig.framework_search_paths
          frameworks_search_paths.should == %w($(PLATFORM_DIR)/Developer/Library/Frameworks)
        end
      end

      #---------------------------------------------------------------------#

      describe '::application_extension_api_only' do
        it 'does not set APPLICATION_EXTENSION_API_ONLY missing in the target' do
          target = fixture_pod_target('integration/Reachability/Reachability.podspec')
          build_settings = pod(target)
          other_swift_flags = build_settings.xcconfig.to_hash['APPLICATION_EXTENSION_API_ONLY']
          other_swift_flags.should.be.nil
        end

        it 'does not set APPLICATION_EXTENSION_API_ONLY when false in the target' do
          target = fixture_pod_target('integration/Reachability/Reachability.podspec')
          target.instance_variable_set(:@application_extension_api_only, false)
          build_settings = pod(target)
          other_swift_flags = build_settings.xcconfig.to_hash['APPLICATION_EXTENSION_API_ONLY']
          other_swift_flags.should.be.nil
        end

        it 'sets APPLICATION_EXTENSION_API_ONLY to YES when true in the target' do
          target = fixture_pod_target('integration/Reachability/Reachability.podspec')
          target.instance_variable_set(:@application_extension_api_only, true)
          build_settings = pod(target)
          other_swift_flags = build_settings.xcconfig.to_hash['APPLICATION_EXTENSION_API_ONLY']
          other_swift_flags.should.== 'YES'
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

      describe '#merge_spec_xcconfig_into_xcconfig' do
        before do
          @build_settings = BuildSettings.new(stub('Target'))
          @xcconfig = Xcodeproj::Config.new
        end

        it 'merges into an empty xcconfig' do
          @build_settings.send(:merge_spec_xcconfig_into_xcconfig, { 'A' => 'A', 'OTHER_LDFLAGS' => '-f Frame', 'EMPTY' => '' }, @xcconfig)
          @xcconfig.to_hash.should == { 'A' => 'A', 'OTHER_LDFLAGS' => '-f Frame', 'EMPTY' => '' }
        end

        it 'merges into an xcconfig with overlapping settings' do
          @xcconfig.merge!('A' => 'NOT A', 'OTHER_LDFLAGS' => '-lLib', 'B' => 'B', 'FRAMEWORK_SEARCH_PATHS' => 'FWSP')
          @build_settings.send(:merge_spec_xcconfig_into_xcconfig, { 'A' => 'A', 'OTHER_LDFLAGS' => %w(-f Frame), 'EMPTY' => [] }, @xcconfig)
          @xcconfig.to_hash.should == { 'A' => 'A', 'B' => 'B', 'FRAMEWORK_SEARCH_PATHS' => 'FWSP', 'OTHER_LDFLAGS' => '-f Frame -l"Lib"', 'EMPTY' => [] }
        end
      end

      #---------------------------------------------------------------------#

      describe 'concerning settings for file accessors' do
        it 'does not propagate framework or libraries from a test specification to an aggregate target' do
          target_definition = fixture_target_definition(:contents => { 'inheritance' => 'complete' })
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
                               :vendored_static_libraries => [config.sandbox.root + 'libStaticLibrary.a'],
                               :vendored_static_artifacts => [config.sandbox.root + 'StaticFramework.framework', config.sandbox.root + 'libStaticLibrary.a'],
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
                            :build_as_static? => false,
                            :build_as_dynamic? => true,
                            :build_settings => [],
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                            :root_spec => spec,
                           )
          pod_target.stubs(:build_settings_for_spec => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target])
          aggregate(aggregate_target).other_ldflags.should.not.include '-framework'
        end

        it 'does not propagate framework or libraries from a app specification to an aggregate target' do
          target_definition = fixture_target_definition(:contents => { 'inheritance' => 'complete' })
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
                               :vendored_static_libraries => [config.sandbox.root + 'libStaticLibrary.a'],
                               :vendored_static_artifacts => [config.sandbox.root + 'StaticFramework.framework', config.sandbox.root + 'libStaticLibrary.a'],
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
                            :build_as_static? => false,
                            :build_as_dynamic? => true,
                            :build_settings => [],
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                            :root_spec => spec,
                           )
          pod_target.stubs(:build_settings_for_spec => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target])
          aggregate(aggregate_target).other_ldflags.should.not.include '-framework'
        end
      end

      describe 'concerning other_ld_flags' do
        it 'other_ld_flags should not include -ObjC when there are not static frameworks' do
          target_definition = fixture_target_definition(:contents => { 'inheritance' => 'complete' })
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
                            :build_as_static? => false,
                            :build_as_dynamic? => true,
                            :build_settings => [],
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                            :root_spec => spec,
                           )
          pod_target.stubs(:build_settings_for_spec => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target], true)
          aggregate(aggregate_target).other_ldflags.should.not.include '-ObjC'
        end

        it 'other_ld_flags should include -ObjC when linking static frameworks' do
          target_definition = fixture_target_definition(:contents => { 'inheritance' => 'complete' })
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
                               :vendored_xcframeworks => [],
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
                            :build_as_static? => true,
                            :build_as_dynamic? => false,
                            :build_settings => [],
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                            :root_spec => spec,
                           )
          pod_target.stubs(:build_settings_for_spec => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target], true)
          aggregate(aggregate_target).other_ldflags.should.include '-ObjC'
        end

        it 'other_ld_flags should include -ObjC when linking vendored static frameworks' do
          target_definition = fixture_target_definition(:contents => { 'inheritance' => 'complete' })
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
                               :vendored_static_artifacts => ['Foo'],
                               :vendored_static_libraries => [],
                               :vendored_dynamic_libraries => [],
                               :vendored_static_frameworks => [],
                               :vendored_dynamic_frameworks => [],
                               :vendored_xcframeworks => [],
                              )
          pod_target = stub('pod_target',
                            :any_vendored_static_artifacts? => true,
                            :file_accessors => [file_accessor],
                            :requires_frameworks? => true,
                            :dependent_targets => [],
                            :recursive_dependent_targets => [],
                            :sandbox => config.sandbox,
                            :include_in_build_config? => true,
                            :should_build? => false,
                            :spec_consumers => [consumer],
                            :build_as_static? => false,
                            :build_as_dynamic? => false,
                            :build_settings => [],
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                            :root_spec => spec,
                           )
          pod_target.stubs(:build_settings_for_spec => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target], true)
          aggregate(aggregate_target).other_ldflags.should.include '-ObjC'
        end

        it 'other_ld_flags should include -ObjC when linking vendored static xcframeworks' do
          target_definition = fixture_target_definition(:contents => { 'inheritance' => 'complete' })
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
                               :vendored_static_artifacts => [1, 2, 3],
                               :vendored_static_libraries => [],
                               :vendored_dynamic_libraries => [],
                               :vendored_static_frameworks => [],
                               :vendored_dynamic_frameworks => [],
                               :vendored_xcframeworks => [],
                              )
          pod_target = stub('pod_target',
                            :any_vendored_static_artifacts? => true,
                            :file_accessors => [file_accessor],
                            :requires_frameworks? => true,
                            :dependent_targets => [],
                            :recursive_dependent_targets => [],
                            :sandbox => config.sandbox,
                            :include_in_build_config? => true,
                            :should_build? => false,
                            :spec_consumers => [consumer],
                            :build_as_static? => false,
                            :build_as_dynamic? => false,
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                            :root_spec => spec,
                            :configuration => 0,
                           )
          pod_target.stubs(:build_settings_for_spec => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target], true)
          aggregate(aggregate_target).other_ldflags.should.include '-ObjC'
        end

        it 'other_ld_flags should include not -ObjC when linking vendored dynamic xcframeworks' do
          target_definition = fixture_target_definition(:contents => { 'inheritance' => 'complete' })
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
                               :vendored_xcframeworks => [],
                              )
          pod_target = stub('pod_target',
                            :any_vendored_static_artifacts? => true,
                            :file_accessors => [file_accessor],
                            :requires_frameworks? => true,
                            :dependent_targets => [],
                            :recursive_dependent_targets => [],
                            :sandbox => config.sandbox,
                            :include_in_build_config? => true,
                            :should_build? => false,
                            :spec_consumers => [consumer],
                            :build_as_static? => false,
                            :build_as_dynamic? => false,
                            :product_basename => 'PodTarget',
                            :target_definitions => [target_definition],
                            :root_spec => spec,
                            :configuration => 0,
                           )
          pod_target.stubs(:build_settings_for_spec => pod(pod_target))
          aggregate_target = fixture_aggregate_target([pod_target], true)
          aggregate(aggregate_target).other_ldflags.should.not.include '-ObjC'
        end
      end

      #---------------------------------------------------------------------#
    end
  end
end
