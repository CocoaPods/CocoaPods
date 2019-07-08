require File.expand_path('../spec_helper', __FILE__)

module Pod
  class Sample
    extend SpecHelper::Fixture

    def self.yaml
      <<-LOCKFILE.strip_heredoc
        PODS:
          - BananaLib (1.0):
            - monkey (< 1.0.9, ~> 1.0.1)
          - JSONKit (1.4)
          - monkey (1.0.8)

        DEPENDENCIES:
          - BananaLib (~> 1.0)
          - JSONKit (from `path/JSONKit.podspec`)

        SPEC REPOS:
          trunk:
            - BananaLib
            - monkey

        EXTERNAL SOURCES:
          JSONKit:
            :podspec: path/JSONKit.podspec

        CHECKOUT OPTIONS:
          JSONKit:
            :podspec: path/JSONKit.podspec

        SPEC CHECKSUMS:
          BananaLib: d46ca864666e216300a0653de197668b12e732a1
          JSONKit: 92ae5f71b77c8dec0cd8d0744adab79d38560949

        PODFILE CHECKSUM: podfile_checksum

        COCOAPODS: #{CORE_VERSION}
      LOCKFILE
    end

    def self.quotation_marks_yaml
      <<-LOCKFILE.strip_heredoc
        PODS:
          - BananaLib (1.0):
            - monkey (< 1.0.9, ~> 1.0.1)
          - JSONKit (1.4)
          - monkey (1.0.8)

        DEPENDENCIES:
          - BananaLib (~> 1.0)
          - JSONKit (from `path/JSONKit.podspec`)

        SPEC REPOS:
          trunk:
            - BananaLib
            - monkey

        EXTERNAL SOURCES:
          JSONKit:
            :podspec: "path/JSONKit.podspec"

        CHECKOUT OPTIONS:
          JSONKit:
            :podspec: path/JSONKit.podspec

        SPEC CHECKSUMS:
          BananaLib: d46ca864666e216300a0653de197668b12e732a1
          JSONKit: '92ae5f71b77c8dec0cd8d0744adab79d38560949'

        PODFILE CHECKSUM: podfile_checksum

        COCOAPODS: #{CORE_VERSION}
      LOCKFILE
    end

    def self.podfile
      podfile = Podfile.new do
        platform :ios
        pod 'BananaLib', '~>1.0'
        pod 'JSONKit', :podspec => 'path/JSONKit.podspec'
      end
      podfile.stubs(:checksum).returns('podfile_checksum')
      podfile
    end

    def self.specs
      repo_path      = 'spec-repos/test_repo/'
      bananalib_path = repo_path + 'Specs/BananaLib/1.0/BananaLib.podspec'
      jsonkit_path   = repo_path + 'Specs/JSONKit/1.4/JSONKit.podspec'

      specs = [
        Specification.from_file(fixture(bananalib_path)),
        Specification.from_file(fixture(jsonkit_path)),
        Specification.new do |s|
          s.name = 'monkey'
          s.version = '1.0.8'
        end,
      ]
      specs
    end

    def self.checkout_options
      {
        'JSONKit' => {
          :podspec => 'path/JSONKit.podspec',
        },
      }
    end

    def self.specs_by_source
      {
        TrunkSource.new(fixture('spec-repos/trunk')) => specs.reject { |s| s.name == 'JSONKit' },
        Source.new(fixture('spec-repos/test_repo')) => [],
      }
    end
  end

  #---------------------------------------------------------------------------#

  describe Lockfile do
    describe 'In general' do
      extend SpecHelper::TemporaryDirectory

      before do
        @tmp_path = temporary_directory + 'Podfile.lock'
      end

      it 'stores the initialization hash' do
        lockfile = Lockfile.new(YAMLHelper.load_string(Sample.yaml))
        lockfile.internal_data.should == YAMLHelper.load_string(Sample.yaml)
      end

      it 'loads from a file' do
        File.open(@tmp_path, 'w') { |f| f.write(Sample.yaml) }
        lockfile = Lockfile.from_file(@tmp_path)
        lockfile.internal_data.should == YAMLHelper.load_string(Sample.yaml)
      end

      it "returns nil if it can't find the initialization file" do
        lockfile = Lockfile.from_file(temporary_directory + 'Podfile.lock_not_existing')
        lockfile.should.nil?
      end

      it 'returns the file in which is defined' do
        File.open(@tmp_path, 'w') { |f| f.write(Sample.yaml) }
        lockfile = Lockfile.from_file(@tmp_path)
        lockfile.defined_in_file.should == @tmp_path
      end

      it "raises if the provided YAML doesn't returns a hash" do
        File.open(@tmp_path, 'w') { |f| f.write('value') }
        should.raise Informative do
          Lockfile.from_file(@tmp_path)
        end.message.should.match /Invalid Lockfile/
      end

      #--------------------------------------#

      before do
        @lockfile = Lockfile.generate(Sample.podfile, Sample.specs, Sample.checkout_options, Sample.specs_by_source)
      end

      it 'returns whether it is equal to another' do
        podfile = Podfile.new do
          platform :ios
          pod 'BananaLib', '~>1.0'
        end
        @lockfile.should == @lockfile
        @lockfile.should.not == Lockfile.generate(podfile, Sample.specs, Sample.checkout_options, Sample.specs_by_source)
      end

      it 'returns the list of the names of the  installed pods' do
        @lockfile.pod_names.should == %w(BananaLib JSONKit monkey)
      end

      it 'returns the versions of a given pod' do
        @lockfile.version('BananaLib').should == Version.new('1.0')
        @lockfile.version('JSONKit').should == Version.new('1.4')
        @lockfile.version('monkey').should == Version.new('1.0.8')
      end

      it 'returns the versions of a given pod handling the case in which the root spec was not stored' do
        @lockfile.stubs(:pod_versions).returns('BananaLib/Subspec' => Version.new(1.0))
        @lockfile.version('BananaLib').should == Version.new('1.0')
      end

      it 'returns the spec repo of a given pod' do
        @lockfile.spec_repo('BananaLib').should == 'trunk'
        @lockfile.spec_repo('JSONKit').should.be.nil
        @lockfile.spec_repo('monkey').should == 'trunk'
      end

      it 'returns the checksum for the given Pod' do
        @lockfile.checksum('BananaLib').should == 'd46ca864666e216300a0653de197668b12e732a1'
      end

      it 'returns the dependencies used for the last installation' do
        json_dep = Dependency.new('JSONKit')
        json_dep.external_source = { :podspec => 'path/JSONKit.podspec' }
        @lockfile.dependencies.should == [
          Dependency.new('BananaLib', '~>1.0'),
          json_dep,
        ]
      end

      it 'returns the spec repo sources' do
        @lockfile.pods_by_spec_repo.should == Hash[Sample.specs_by_source.map do |source, specs|
          next unless source.name == 'trunk'
          ['trunk', specs.map(&:name)]
        end.compact]
      end

      it 'returns the spec repo sources when that section is missing' do
        @lockfile = Lockfile.new({})
        @lockfile.pods_by_spec_repo.should == {}
      end

      it 'only includes root names in spec repo sources' do
        @lockfile = Lockfile.generate(Sample.podfile, [], {}, TrunkSource.new(fixture('spec-repos/trunk')) => Pod::Spec.new do |s|
                                                                                                                s.name = 'foo'
                                                                                                                s.version = '1.0.0'
                                                                                                                s.subspec 'Core'
                                                                                                                s.subspec 'NotCore'
                                                                                                              end.recursive_subspecs)
        @lockfile.pods_by_spec_repo.should == {
          'trunk' => %w(foo),
        }
      end

      it 'includes the external source information in the generated dependencies' do
        dep = @lockfile.dependencies.find { |d| d.name == 'JSONKit' }
        dep.external_source.should == { :podspec => 'path/JSONKit.podspec' }
      end

      it 'returns the dependency that locks the pod with the given name to the installed version' do
        json_dep = Dependency.new('JSONKit', '1.4')
        json_dep.external_source = { :podspec => 'path/JSONKit.podspec' }
        result = @lockfile.dependencies_to_lock_pod_named('JSONKit')
        result.should == [json_dep]
      end

      it 'raises if there is a request for a locking dependency for a not stored Pod' do
        should.raise StandardError do
          @lockfile.dependencies_to_lock_pod_named('Missing')
        end.message.should.match /without a known dependency/
      end

      it 'returns the version of CocoaPods which generated the lockfile' do
        @lockfile.cocoapods_version.should == Version.new(CORE_VERSION)
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Comparison with a Podfile' do
      before do
        @podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit'
        end
        @specs = [
          Specification.new do |s|
            s.name = 'BlocksKit'
            s.version = '1.0.0'
          end,
          Specification.new do |s|
            s.name = 'JSONKit'
            s.version = '1.4'
          end]
        @checkout_options = {}
        @specs_by_source = {}
        @lockfile = Lockfile.generate(@podfile, @specs, @checkout_options, @specs_by_source)
      end

      it 'detects an added Pod' do
        podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit'
          pod 'TTTAttributedLabel'
        end
        @lockfile.detect_changes_with_podfile(podfile).should == {
          :changed => [],
          :removed => [],
          :unchanged => %w(BlocksKit JSONKit),
          :added => ['TTTAttributedLabel'],
        }
      end

      it 'detects a removed Pod' do
        podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
        end
        @lockfile.detect_changes_with_podfile(podfile).should == {
          :changed => [],
          :removed => ['JSONKit'],
          :unchanged => ['BlocksKit'],
          :added => [],
        }
      end

      it 'detects Pods whose version changed' do
        podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit', '> 1.4'
        end
        @lockfile.detect_changes_with_podfile(podfile).should == {
          :changed => ['JSONKit'],
          :removed => [],
          :unchanged => ['BlocksKit'],
          :added => [],
        }
      end

      it "it doesn't mark as changed Pods whose version changed but is still compatible with the Podfile" do
        podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit', '> 1.0'
        end
        @lockfile.detect_changes_with_podfile(podfile).should == {
          :changed => [],
          :removed => [],
          :unchanged => %w(BlocksKit JSONKit),
          :added => [],
        }
      end

      it 'detects Pods whose external source changed' do
        podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit', :git => 'example1.com'
        end
        @lockfile.detect_changes_with_podfile(podfile).should == {
          :changed => ['JSONKit'],
          :removed => [],
          :unchanged => ['BlocksKit'],
          :added => [],
        }
        @lockfile = Lockfile.generate(podfile, @specs, @checkout_options, @specs_by_source)
        podfile = Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit', :git => 'example2.com'
        end
        @lockfile.detect_changes_with_podfile(podfile).should == {
          :changed => ['JSONKit'],
          :removed => [],
          :unchanged => ['BlocksKit'],
          :added => [],
        }
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Serialization' do
      before do
        @lockfile = Lockfile.generate(Sample.podfile, Sample.specs, Sample.checkout_options, Sample.specs_by_source)
      end

      it 'can be store itself at the given path' do
        path = SpecHelper.temporary_directory + 'Podfile.lock'
        @lockfile.write_to_disk(path)
        loaded = Lockfile.from_file(path)
        loaded.should == @lockfile
      end

      it "won't write to disk if the equivalent lockfile is already there" do
        path = SpecHelper.temporary_directory + 'Podfile.lock'
        old_yaml = %(---\nhi: "./hi"\n)
        path.open('w') { |f| f.write old_yaml }
        @lockfile.stubs(:to_hash).returns('hi' => './hi')
        @lockfile.stubs(:to_yaml).returns("---\nhi: ./hi\n")
        path.expects(:open).with('w').never
        @lockfile.write_to_disk(path)
        path.read.should == old_yaml
      end

      it 'overwrites a different lockfile' do
        path = SpecHelper.temporary_directory + 'Podfile.lock'
        path.delete if path.exist?
        @lockfile.write_to_disk(path)

        @lockfile = Lockfile.new('COCOAPODS' => '0.0.0')
        @lockfile.write_to_disk(path)

        @lockfile.should == Lockfile.from_file(path)
      end

      it 'fix strange quotation marks in lockfile' do
        yaml_string = Sample.quotation_marks_yaml
        yaml_string = yaml_string.tr("'", '')
        yaml_string = yaml_string.tr('"', '')
        yaml_string.should == Sample.yaml
      end

      it 'generates a hash representation' do
        hash = @lockfile.to_hash
        hash.should == {
          'PODS' => [
            { 'BananaLib (1.0)' => ['monkey (< 1.0.9, ~> 1.0.1)'] },
            'JSONKit (1.4)', 'monkey (1.0.8)'],
          'DEPENDENCIES' => ['BananaLib (~> 1.0)', 'JSONKit (from `path/JSONKit.podspec`)'],
          'SPEC REPOS' => { 'trunk' => %w(BananaLib monkey) },
          'EXTERNAL SOURCES' => { 'JSONKit' => { :podspec => 'path/JSONKit.podspec' } },
          'CHECKOUT OPTIONS' => { 'JSONKit' => { :podspec => 'path/JSONKit.podspec' } },
          'SPEC CHECKSUMS' => { 'BananaLib' => 'd46ca864666e216300a0653de197668b12e732a1', 'JSONKit' => '92ae5f71b77c8dec0cd8d0744adab79d38560949' },
          'PODFILE CHECKSUM' => 'podfile_checksum',
          'COCOAPODS' => CORE_VERSION,
        }
      end

      it 'handles when the podfile has no checksum' do
        podfile = Sample.podfile
        podfile.stubs(:checksum).returns(nil)
        @lockfile = Lockfile.generate(podfile, Sample.specs, Sample.checkout_options, Sample.specs_by_source)
        @lockfile.to_hash.should.not.key?('PODFILE CHECKSUM')
      end

      it 'generates an ordered YAML representation' do
        @lockfile.to_yaml.should == Sample.yaml
      end

      it 'generates a valid YAML representation' do
        YAMLHelper.load_string(@lockfile.to_yaml).should ==
          YAMLHelper.load_string(Sample.yaml)
      end

      it 'serializes correctly external dependencies' do
        podfile = Podfile.new do
          platform :ios
          pod 'BananaLib',  :git => 'www.example.com', :tag => '1.0'
        end
        specs = [
          Specification.new do |s|
            s.name = 'BananaLib'
            s.version = '1.0'
          end,
          Specification.new do |s|
            s.name = 'monkey'
            s.version = '1.0.8'
          end,
        ]
        checkout_options = {
          'BananaLib' => { :git => 'www.example.com', :tag => '1.0' },
        }
        specs_by_source = { TrunkSource.new(fixture('spec-repos/trunk')) => specs.select { |s| s.name == 'monkey' } }
        lockfile = Lockfile.generate(podfile, specs, checkout_options, specs_by_source)
        lockfile.internal_data['DEPENDENCIES'][0].should == 'BananaLib (from `www.example.com`, tag `1.0`)'
        lockfile.internal_data['EXTERNAL SOURCES']['BananaLib'].should == { :git => 'www.example.com', :tag => '1.0' }
      end

      describe 'when the Podfile is empty' do
        before do
          @lockfile = Lockfile.generate(Podfile.new, [], [], {})
        end

        it 'generates a lockfile with only the version' do
          @lockfile.to_yaml.should == "COCOAPODS: #{CORE_VERSION}\n"
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Generation from a Podfile' do
      before do
        @lockfile = Lockfile.generate(Sample.podfile, Sample.specs, Sample.checkout_options, Sample.specs_by_source)
      end

      it 'stores the information of the installed pods and of their dependencies' do
        @lockfile.internal_data['PODS'].should == [
          { 'BananaLib (1.0)' => ['monkey (< 1.0.9, ~> 1.0.1)'] },
          'JSONKit (1.4)',
          'monkey (1.0.8)',
        ]
      end

      it 'stores the information of the dependencies of the Podfile' do
        @lockfile.internal_data['DEPENDENCIES'].should == [
          'BananaLib (~> 1.0)', 'JSONKit (from `path/JSONKit.podspec`)'
        ]
      end

      it 'stores the information of the external sources' do
        @lockfile.internal_data['EXTERNAL SOURCES'].should == {
          'JSONKit' => { :podspec => 'path/JSONKit.podspec' },
        }
      end

      it 'stores the checksum of the specifications' do
        @lockfile.internal_data['SPEC CHECKSUMS'].should == {
          'BananaLib' => 'd46ca864666e216300a0653de197668b12e732a1',
          'JSONKit' => '92ae5f71b77c8dec0cd8d0744adab79d38560949',
        }
      end

      it 'store the version of the CocoaPods Core gem' do
        @lockfile.internal_data['COCOAPODS'].should == CORE_VERSION
      end

      it 'it includes all the information that it is expected to store' do
        @lockfile.internal_data.should == YAMLHelper.load_string(Sample.yaml)
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do
      describe '#generate_pods_data' do
        it 'groups multiple dependencies for the same pod' do
          specs = [
            Specification.new do |s|
              s.name = 'BananaLib'
              s.version = '1.0'
              s.dependency 'monkey', '< 1.0.9'
            end,
            Specification.new do |s|
              s.name = 'BananaLib'
              s.version = '1.0'
              s.dependency 'tree', '~> 1.0.1'
            end,
          ]
          pods_data = Lockfile.send(:generate_pods_data, specs)
          pods_data.should == [
            { 'BananaLib (1.0)' => ['monkey (< 1.0.9)', 'tree (~> 1.0.1)'] },
          ]
        end

        it 'sort pods by lowercase' do
          specs = [
            Specification.new do |s|
              s.name = 'a'
              s.version = '1.0'
              s.dependency 'monkey', '< 1.0.9'
            end,
            Specification.new do |s|
              s.name = 'b'
              s.version = '1.0'
            end,
            Specification.new do |s|
              s.name = 'C'
              s.version = '1.0'
              s.dependency 'tree', '~> 1.0.1'
            end,
          ]
          pods_data = Lockfile.send(:generate_pods_data, specs)
          pods_data.should == [
            { 'a (1.0)' => ['monkey (< 1.0.9)'] },
            'b (1.0)',
            { 'C (1.0)' => ['tree (~> 1.0.1)'] },
          ]
        end

        it 'sorts dependencies for the pod by lowercase' do
          specs = [
            Specification.new do |s|
              s.name = 'BananaLib'
              s.version = '1.0'
              s.dependency 'a', '< 1.0.9'
            end,
            Specification.new do |s|
              s.name = 'BananaLib'
              s.version = '1.0'
              s.dependency 'b', '< 1.0.8'
            end,
            Specification.new do |s|
              s.name = 'BananaLib'
              s.version = '1.0'
              s.dependency 'C', '~> 1.0.1'
            end,
          ]
          pods_data = Lockfile.send(:generate_pods_data, specs)
          pods_data.should == [
            { 'BananaLib (1.0)' => ['a (< 1.0.9)', 'b (< 1.0.8)', 'C (~> 1.0.1)'] },
          ]
        end
      end

      describe '#generate_dependencies_data' do
        it 'sorts dependencies by lowercase' do
          podfile = Podfile.new do
            pod 'a'
            pod 'b'
            pod 'C'
          end
          dependencies_data = Lockfile.send(:generate_dependencies_data, podfile)
          dependencies_data.should == %w(a b C)
        end
      end

      describe '#generate_spec_repos' do
        it 'sorts specs per spec repo by lowercase' do
          spec_repos = {
            TrunkSource.new(fixture('spec-repos/trunk')) => [
              Specification.new do |s|
                s.name = 'a'
                s.version = '1.0'
              end,
              Specification.new do |s|
                s.name = 'b'
                s.version = '1.0'
              end,
              Specification.new do |s|
                s.name = 'C'
                s.version = '1.0'
              end,
            ],
          }
          spec_repos_data = Lockfile.send(:generate_spec_repos, spec_repos)
          spec_repos_data.should == { 'trunk' => %w(a b C) }
        end
      end
    end
  end
end
