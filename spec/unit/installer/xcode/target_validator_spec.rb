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
          installation_options = Installer::InstallationOptions.new.tap do |options|
            options.integrate_targets = false
          end

          @analyzer = Analyzer.new(config.sandbox, podfile, lockfile).tap do |analyzer|
            analyzer.installation_options = installation_options
          end
          result = @analyzer.analyze

          aggregate_targets = result.targets
          pod_targets = aggregate_targets.map(&:pod_targets).flatten.uniq
          sandbox.create_file_accessors(pod_targets)

          TargetValidator.new(aggregate_targets, pod_targets)
        end

        describe '#verify_no_duplicate_framework_and_library_names' do
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

            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']])
            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => false, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']])

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

            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']])
            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => true, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']])

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
            orangeframework_pod_target = stub(:name => 'OrangeFramework', :uses_swift? => false, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']])
            matryoshka_pod_target = stub(:name => 'matryoshka', :uses_swift? => false, :target_definitions => [podfile.target_definitions['SampleProject'], podfile.target_definitions['TestRunner']])

            @validator = TargetValidator.new([], [orangeframework_pod_target, matryoshka_pod_target])
            lambda { @validator.validate! }.should.not.raise
          end
        end

        #-------------------------------------------------------------------------#

        describe '#verify_framework_usage' do
          it 'raises when Swift pods are used without explicit `use_frameworks!`' do
            fixture_path = ROOT + 'spec/fixtures'
            config.repos_dir = fixture_path + 'spec-repos'
            podfile = Pod::Podfile.new do
              platform :ios, '8.0'
              project 'SampleProject/SampleProject'
              pod 'OrangeFramework', :path => (fixture_path + 'orange-framework').to_s
              pod 'matryoshka',      :path => (fixture_path + 'matryoshka').to_s
              target 'SampleProject'
            end
            lockfile = generate_lockfile

            @validator = create_validator(config.sandbox, podfile, lockfile)
            should.raise(Informative) { @validator.validate! }.message.should.match /use_frameworks/
          end
        end
      end
    end
  end
end
