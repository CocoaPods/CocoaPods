require File.expand_path('../../../../spec_helper', __FILE__)

module Pod
  class Installer
    class Xcode
      describe TargetValidator do
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

        # @return [AnalysisResult]
        #
        def create_validator(sandbox, podfile, lockfile)
          sandbox.specifications_root.mkpath
          @analyzer = Analyzer.new(sandbox, podfile, lockfile, nil, true, false)
          result = @analyzer.analyze

          aggregate_targets = result.targets
          pod_targets = aggregate_targets.flat_map(&:pod_targets).uniq

          TargetValidator.new(aggregate_targets, pod_targets, podfile.installation_options)
        end

        describe '#verify_no_duplicate_framework_and_library_names' do
          before do
            SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project')
          end

          it 'detects duplicate library names' do
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).
              returns([Pathname('a/libBananaStaticLib.a')]).then.
              returns([Pathname('b/libBananaStaticLib.a')])
            Pod::Specification.any_instance.stubs(:dependencies).returns([])
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Pod::Podfile.new do
              platform :ios, '8.0'
              install! 'cocoapods', :integrate_targets => false
              project(fixture_path + 'SampleProject/SampleProject').to_s
              pod 'monkey',    :path => (fixture_path + 'monkey').to_s
              pod 'BananaLib', :path => (fixture_path + 'banana-lib').to_s
              target 'SampleProject'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /conflict.*bananastaticlib/
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
              install! 'cocoapods', :integrate_targets => false
              project(fixture_path + 'SampleProject/SampleProject').to_s
              pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              pod 'monkey',          :path => (fixture_path + 'monkey').to_s
              target 'SampleProject'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /conflict.*monkey/
          end

          it 'allows duplicate references to the same expanded framework path' do
            Sandbox::FileAccessor.any_instance.stubs(:vendored_frameworks).returns([fixture('monkey/dynamic-monkey.framework')])
            Pod::Xcode::LinkageAnalyzer.stubs(:dynamic_binary?).returns(true)
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Pod::Podfile.new do
              platform :ios, '8.0'
              install! 'cocoapods', :integrate_targets => false
              project(fixture_path + 'SampleProject/SampleProject').to_s
              use_frameworks!
              pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
              pod 'monkey',          :path => (fixture_path + 'monkey').to_s
              target 'SampleProject'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.not.raise(Informative) { @validator.validate! }
          end

          it 'including multiple subspecs from the same pod in a target does not result in duplicate frameworks' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Pod::Podfile.new do
              platform :ios, '9.3'
              project(fixture_path + 'Sample Extensions Project/Sample Extensions Project').to_s
              use_frameworks!

              target 'Sample Extensions Project' do
                pod 'matryoshka/Foo',       :path => (fixture_path + 'matryoshka').to_s
                pod 'matryoshka',           :path => (fixture_path + 'matryoshka').to_s
              end

              target 'Today Extension' do
                pod 'matryoshka/Foo',       :path => (fixture_path + 'matryoshka').to_s
              end
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.not.raise(Informative) { @validator.validate! }
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
              project(fixture_path + 'SampleProject/SampleProject').to_s
              use_frameworks!
              pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
              pod 'CoconutLib',      :path => (fixture_path + 'coconut-lib').to_s
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              pod 'monkey',          :path => (fixture_path + 'monkey').to_s
              target 'SampleProject'
            end
            @podfile.target_definitions['SampleProject'].stubs(:swift_version).returns('3.0')

            @lockfile = generate_lockfile

            @file = Pathname('/yolo.m')
            @file.stubs(:realpath).returns(@file)

            @lib_thing = Pathname('/libThing.a')
            @lib_thing.stubs(:realpath).returns(@lib_thing)
          end

          it 'detects transitive static dependencies which are linked directly to the user target' do
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /transitive.*monkey.a/
          end

          it 'detects transitive static dependencies which are linked directly to the user target with stubbing' do
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /transitive.*libThing/
          end

          it 'allows transitive static dependencies which contain other source code' do
            Sandbox::FileAccessor.any_instance.stubs(:source_files).returns([@file])
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.not.raise(Informative) { @validator.validate! }
          end

          it 'allows transitive static dependencies when both dependencies are linked against the user target' do
            PodTarget.any_instance.stubs(:should_build? => false)
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.not.raise(Informative) { @validator.validate! }
          end
        end

        describe '#verify_no_incorrect_static_framework_transitive_dependencies_with_static_frameworks' do
          before do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            @podfile = Pod::Podfile.new do
              install! 'cocoapods', 'integrate_targets' => false
              platform :ios, '8.0'
              project(fixture_path + 'SampleProject/SampleProject').to_s
              use_frameworks!
              pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
              pod 'CoconutLib',      :path => (fixture_path + 'coconut-lib').to_s
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'static-matryoshka').to_s
              pod 'monkey',          :path => (fixture_path + 'monkey').to_s
              target 'SampleProject'
            end
            @podfile.target_definitions['SampleProject'].stubs(:swift_version).returns('3.0')

            @lockfile = generate_lockfile

            @file = Pathname('/yolo.m')
            @file.stubs(:realpath).returns(@file)

            @lib_thing = Pathname('/libThing.a')
            @lib_thing.stubs(:realpath).returns(@lib_thing)
          end

          it 'detects transitive static dependencies which are linked directly to the user target' do
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /transitive.*monkey.a/
          end

          it 'detects transitive static dependencies which are linked directly to the user target with stubbing' do
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /transitive.*libThing/
          end

          it 'detects transitive static dependencies to static frameworks from dynamic library pods' do
            Sandbox::FileAccessor.any_instance.stubs(:source_files).returns([@file])
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /transitive.*matryoshka/
          end

          it 'allows transitive static dependencies when both dependencies are linked against the user target' do
            PodTarget.any_instance.stubs(:should_build? => false)
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.not.raise(Informative) { @validator.validate! }
          end

          it 'allows transitive static dependencies when building a static framework' do
            PodTarget.any_instance.stubs(:build_type => BuildType.static_framework)
            Sandbox::FileAccessor.any_instance.stubs(:vendored_libraries).returns([@lib_thing])
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.not.raise(Informative) { @validator.validate! }
          end
        end

        describe '#verify_no_static_framework_transitive_dependencies_with_static_framework' do
          before do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            @podfile = Pod::Podfile.new do
              install! 'cocoapods', 'integrate_targets' => false
              platform :ios, '8.0'
              project(fixture_path + 'SampleProject/SampleProject').to_s
              use_frameworks!
              pod 'matryoshka',      :path => (fixture_path + 'static-matryoshka').to_s
              pod 'monkey',          :path => (fixture_path + 'monkey').to_s
              target 'SampleProject'
            end
            @lockfile = generate_lockfile

            @file = Pathname('/yolo.m')
            @file.stubs(:realpath).returns(@file)
          end

          it 'allows transitive static dependencies when building a static framework' do
            @validator = create_validator(config.sandbox, @podfile, @lockfile)
            should.not.raise(Informative) { @validator.send :verify_no_static_framework_transitive_dependencies }
          end
        end

        #-------------------------------------------------------------------------#

        describe '#verify_swift_pods_swift_version' do
          it 'raises when targets integrate the same swift pod but have different swift versions' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '8.0'
              install! 'cocoapods', :integrate_targets => false
              use_frameworks!
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            podfile.target_definition_list.find { |td| td.name == 'SampleProject' }.swift_version = '3.0'
            podfile.target_definition_list.find { |td| td.name == 'TestRunner' }.swift_version = '2.3'
            e = should.raise Informative do
              @validator.validate!
            end

            e.message.should.match /Unable to determine Swift version for the following pods:/
            e.message.should.include '`OrangeFramework` is integrated by multiple targets that use a different Swift version: ' \
              '`SampleProject` (Swift 3.0) and `TestRunner` (Swift 2.3).'
            e.message.should.not.include '`matryoshka` is integrated by multiple targets that use a different Swift version: ' \
              '`SampleProject` (Swift 3.0) and `TestRunner` (Swift 2.3).'
          end

          it 'raises when swift pods integrated into targets that do not specify a swift version' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              use_frameworks!
              platform :ios, '8.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            e = should.raise Informative do
              @validator.validate!
            end
            e.message.should.match /Unable to determine Swift version for the following pods:/
            e.message.should.include '`OrangeFramework` does not specify a Swift version and none of the targets ' \
              '(`SampleProject` and `TestRunner`) integrating it have the `SWIFT_VERSION` attribute set. Please contact ' \
              'the author or set the `SWIFT_VERSION` attribute in at least one of the targets that integrate this pod.'
            e.message.should.not.include '`matryoshka` does not specify a Swift version and none of the targets ' \
              '(`SampleProject` and `TestRunner`) integrating it have the `SWIFT_VERSION` attribute set. Please contact ' \
            'the author or set the `SWIFT_VERSION` attribute in at least one of the targets that integrate this pod.'
          end

          it 'does not raise when targets integrate the same pod but only one of the targets is a swift target' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project 'SampleProject/SampleProject'
              use_frameworks!
              platform :ios, '8.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject' do
                current_target_definition.swift_version = '3.0'
              end
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            lambda { @validator.validate! }.should.not.raise
          end

          it 'does not raise when targets integrate the same pod but none of the pod targets use swift' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              use_frameworks!
              platform :ios, '8.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            podfile.target_definition_list.find { |td| td.name == 'SampleProject' }.swift_version = '3.0'
            podfile.target_definition_list.find { |td| td.name == 'TestRunner' }.swift_version = '2.3'
            lambda { @validator.validate! }.should.not.raise
          end

          it 'does not raise when targets with different Swift versions integrate the same pod that specifies swift version attribute' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              use_frameworks!
              platform :ios, '8.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            podfile.target_definition_list.find { |td| td.name == 'SampleProject' }.swift_version = '3.0'
            podfile.target_definition_list.find { |td| td.name == 'TestRunner' }.swift_version = '2.3'
            @validator.pod_targets.find { |pt| pt.name == 'OrangeFramework' }.stubs(:spec_swift_versions).returns(['4.0'])
            @validator.pod_targets.find { |pt| pt.name == 'OrangeFramework' }.stubs(:swift_version).returns('4.0')
            @validator.pod_targets.find { |pt| pt.name == 'matryoshka' }.stubs(:spec_swift_versions).returns(['3.2'])
            @validator.pod_targets.find { |pt| pt.name == 'matryoshka' }.stubs(:swift_version).returns('3.2')
            lambda { @validator.validate! }.should.not.raise
          end

          it 'raises an error if a pods swift versions are not satisfied by the targets of the requirements' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'MultiSwift', :path => (fixture_path + 'multi-swift').to_s
              supports_swift_versions '< 3.0'
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            e = should.raise Informative do
              @validator.validate!
            end
            e.message.should.match /Unable to determine Swift version for the following pods:/
            e.message.should.include 'MultiSwift` does not specify a Swift version (`3.2` and `4.0`) that is satisfied by ' \
              'any of targets (`SampleProject` and `TestRunner`) integrating it.'
          end

          it 'does not crash on swift version check with deduplicate_targets' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false, :deduplicate_targets => false
              pod 'MultiSwift', :path => (fixture_path + 'multi-swift').to_s
              supports_swift_versions '< 3.0'
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            e = should.raise Informative do
              @validator.validate!
            end
            e.message.should.match /Unable to determine Swift version for the following pods:/
            e.message.should.include 'MultiSwift-Pods-SampleProject` does not specify a Swift version (`3.2` and `4.0`) that is satisfied by ' \
             'any of targets (`SampleProject`) integrating it.'
            e.message.should.include 'MultiSwift-Pods-TestRunner` does not specify a Swift version (`3.2` and `4.0`) that is satisfied by ' \
             'any of targets (`TestRunner`) integrating it.'
          end

          it 'does not crash if targets are missing' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            @validator.stubs(:pod_targets).returns([stub('MultiSwift',
                                                         :uses_swift? => true,
                                                         :swift_version => nil,
                                                         :dependent_targets => [],
                                                         :spec_swift_versions => ['4.0'])])
            lambda { @validator.validate! }.should.not.raise
          end

          it 'does not raise an error if a pods swift versions are satisfied by the targets requirements' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'MultiSwift', :path => (fixture_path + 'multi-swift').to_s
              supports_swift_versions '> 3.0'
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            lambda { @validator.validate! }.should.not.raise
          end
        end

        describe '#verify_swift_pods_have_module_dependencies' do
          it 'raises when a swift target depends upon a target that does not define a module' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s, :modular_headers => true
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s, :modular_headers => false
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            @validator.pod_targets.find { |pt| pt.name == 'OrangeFramework' }.stubs(:spec_swift_versions).returns(['4.0'])
            @validator.pod_targets.find { |pt| pt.name == 'OrangeFramework' }.stubs(:swift_version).returns('4.0')
            e = lambda { @validator.validate! }.should.raise Informative
            e.message.should.include <<-EOS.strip_heredoc.strip
              [!] The following Swift pods cannot yet be integrated as static libraries:

              The Swift pod `OrangeFramework` depends upon `matryoshka`, which does not define modules. To opt into those targets generating module maps (which is necessary to import them from Swift when building as static libraries), you may set `use_modular_headers!` globally in your Podfile, or specify `:modular_headers => true` for particular dependencies.
            EOS
          end

          it 'does not raise when a swift target depends upon a target that is not built' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s, :modular_headers => true
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            podfile.target_definition_list.find { |td| td.name == 'SampleProject' }.swift_version = '3.0'
            podfile.target_definition_list.find { |td| td.name == 'TestRunner' }.swift_version = '3.0'
            @validator.pod_targets.find { |pt| pt.name == 'matryoshka' }.stubs(:should_build?).returns(false)
            lambda { @validator.validate! }.should.not.raise
          end
        end

        describe '#verify_no_multiple_project_names' do
          it 'does not raise if the project name of a pod is only set once' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false, :generate_multiple_pod_projects => true
              pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s, :project_name => 'CustomProjectName'
              target 'SampleProject'
              target 'TestRunner'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            lambda { @validator.validate! }.should.not.raise
          end

          it 'does not when the same project name is used across all targets' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false, :generate_multiple_pod_projects => true
              target 'SampleProject' do
                pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s, :project_name => 'ProjectName1'
              end
              target 'TestRunner' do
                pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s, :project_name => 'ProjectName1'
              end
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            lambda { @validator.validate! }.should.not.raise
          end

          it 'raises when two different project names for a pod are specified with multiple projects option enabled' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false, :generate_multiple_pod_projects => true
              target 'SampleProject' do
                pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s, :project_name => 'ProjectName1'
              end
              target 'TestRunner' do
                pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s, :project_name => 'ProjectName2'
              end
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            e = lambda { @validator.validate! }.should.raise Informative
            e.message.should.include <<-EOS.strip_heredoc.strip
              [!] The following pods cannot be integrated:

              - `matryoshka` specifies multiple project names (`ProjectName1` and `ProjectName2`) in different targets (`SampleProject` and `TestRunner`).
            EOS
          end

          it 'does not raise when two different project names for a pod are specified with multiple project option disabled' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project(fixture_path + 'SampleProject/SampleProject').to_s
              platform :ios, '10.0'
              install! 'cocoapods', :integrate_targets => false, :generate_multiple_pod_projects => false
              target 'SampleProject' do
                pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s, :project_name => 'ProjectName1'
              end
              target 'TestRunner' do
                pod 'matryoshka', :path => (fixture_path + 'matryoshka').to_s, :project_name => 'ProjectName2'
              end
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            lambda { @validator.validate! }.should.not.raise
          end
        end
      end
    end
  end
end
