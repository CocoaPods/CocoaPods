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
        def create_validator(sandbox, podfile, lockfile, integrate_targets = false)
          installation_options = Installer::InstallationOptions.new.tap do |options|
            options.integrate_targets = integrate_targets
          end

          sandbox.specifications_root.mkpath
          @analyzer = Analyzer.new(sandbox, podfile, lockfile).tap do |analyzer|
            analyzer.installation_options = installation_options
          end
          result = @analyzer.analyze

          aggregate_targets = result.targets
          pod_targets = aggregate_targets.flat_map(&:pod_targets).uniq

          TargetValidator.new(aggregate_targets, pod_targets)
        end

        describe '#verify_no_duplicate_framework_and_library_names' do
          before do
            SpecHelper.create_sample_app_copy_from_fixture('Sample Extensions Project')
          end

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

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /conflict.*bananalib/
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

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /conflict.*monkey/
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

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.not.raise(Informative) { @validator.validate! }
          end

          it 'including multiple subspecs from the same pod in a target does not result in duplicate frameworks' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Pod::Podfile.new do
              platform :ios, '9.3'
              project 'Sample Extensions Project/Sample Extensions Project'
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

            @validator = create_validator(config.sandbox, podfile, lockfile, true)
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
              project 'SampleProject/SampleProject'
              use_frameworks!
              pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
              pod 'CoconutLib',      :path => (fixture_path + 'coconut-lib').to_s
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
              project 'SampleProject/SampleProject'
              use_frameworks!
              pod 'BananaLib',       :path => (fixture_path + 'banana-lib').to_s
              pod 'CoconutLib',      :path => (fixture_path + 'coconut-lib').to_s
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'static-matryoshka').to_s
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
            PodTarget.any_instance.stubs(:static_framework? => true)
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
              project 'SampleProject/SampleProject'
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

        describe '#verify_no_pods_used_with_multiple_swift_versions' do
          it 'raises when targets integrate the same swift pod but have different swift versions' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project 'SampleProject/SampleProject'
              platform :ios, '8.0'
              use_frameworks!
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end

            podfile.target_definitions['SampleProject'].stubs(:swift_version).returns('3.0')
            podfile.target_definitions['TestRunner'].stubs(:swift_version).returns('2.3')

            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => nil)
            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => false, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => nil)

            @validator = TargetValidator.new([], [orangeframework_pod_target, matryoshka_pod_target])
            e = should.raise Informative do
              @validator.validate!
            end
            e.message.should.match /The following pods are integrated into targets that do not have the same Swift version:/
            e.message.should.include 'OrangeFramework required by SampleProject (Swift 3.0), TestRunner (Swift 2.3)'
            e.message.should.not.include 'matryoshka required by SampleProject (Swift 3.0), TestRunner (Swift 2.3)'
          end

          it 'does not raise when targets integrate the same pod but only one of the targets is a swift target' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project 'SampleProject/SampleProject'
              use_frameworks!
              platform :ios, '8.0'
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end

            podfile.target_definitions['SampleProject'].stubs(:swift_version).returns('3.0')
            # when the swift version is unset at the project level, but set in one target, swift_version is nil
            podfile.target_definitions['TestRunner'].stubs(:swift_version).returns(nil)

            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => nil, :dependent_targets => [])
            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => nil, :dependent_targets => [])

            @validator = TargetValidator.new([], [orangeframework_pod_target, matryoshka_pod_target])
            lambda { @validator.validate! }.should.not.raise
          end

          it 'does not raise when targets integrate the same pod but none of the pod targets use swift' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project 'SampleProject/SampleProject'
              use_frameworks!
              platform :ios, '8.0'
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end

            podfile.target_definitions['SampleProject'].stubs(:swift_version).returns('3.0')
            podfile.target_definitions['TestRunner'].stubs(:swift_version).returns('2.3')

            # Pretend none of the pod targets use swift, even if the target definitions they are linked with do have different Swift versions.
            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => false, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => nil)
            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => false, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => nil)

            @validator = TargetValidator.new([], [orangeframework_pod_target, matryoshka_pod_target])
            lambda { @validator.validate! }.should.not.raise
          end

          it 'does not raise when targets with different Swift versions integrate the same pod that specifies swift version attribute' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project 'SampleProject/SampleProject'
              use_frameworks!
              platform :ios, '8.0'
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end

            podfile.target_definitions['SampleProject'].stubs(:swift_version).returns('3.0')
            podfile.target_definitions['TestRunner'].stubs(:swift_version).returns('2.3')

            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => '4.0', :dependent_targets => [])
            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']], :spec_swift_version => '3.2', :dependent_targets => [])

            @validator = TargetValidator.new([], [orangeframework_pod_target, matryoshka_pod_target])
            lambda { @validator.validate! }.should.not.raise
          end

          it 'raises when a swift target depends upon a target that does not define a module' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project 'SampleProject/SampleProject'
              platform :ios, '10.0'
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end

            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => false,
                                         :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']],
                                         :should_build? => true, :defines_module? => false, :dependent_targets => [])
            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => true,
                                              :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']],
                                              :should_build? => true, :defines_module? => true, :dependent_targets => [matryoshka_pod_target], :spec_swift_version => '4.0')

            @validator = TargetValidator.new([], [orangeframework_pod_target, matryoshka_pod_target])
            e = lambda { @validator.validate! }.should.raise Informative
            e.message.should.include <<-EOS.strip_heredoc.strip
              [!] The following Swift pods cannot yet be integrated as static libraries:

              The Swift pod `OrangeFramework` depends upon `matryoshka`, which do not define modules. To opt into those targets generating module maps (which is necessary to import them from Swift when building as static libraries), you may set `use_modular_headers!` globally in your Podfile, or specify `:modular_headers => true` for particular dependencies.
            EOS
          end

          it 'does not raise when a swift target depends upon a target thatis not built' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Podfile.new do
              project 'SampleProject/SampleProject'
              platform :ios, '10.0'
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
              target 'TestRunner'
            end

            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => false,
                                         :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']],
                                         :should_build? => false, :defines_module? => false, :dependent_targets => [])
            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => true,
                                              :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']],
                                              :should_build? => true, :defines_module? => true, :dependent_targets => [matryoshka_pod_target], :spec_swift_version => '4.0')

            @validator = TargetValidator.new([], [orangeframework_pod_target, matryoshka_pod_target])
            lambda { @validator.validate! }.should.not.raise
          end
        end
      end
    end
  end
end
