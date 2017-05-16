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
