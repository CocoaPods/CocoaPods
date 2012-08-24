require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Lockfile" do

  describe "In general" do
    extend SpecHelper::TemporaryDirectory

    def sample
      text = <<-LOCKFILE.strip_heredoc
PODS:
- BananaLib (1.0):
  - monkey (< 1.0.9, ~> 1.0.1)
- monkey (1.0.8)

DEPENDENCIES:
- BananaLib (~> 1.0)

SPEC CHECKSUMS:
  BananaLib: !binary |-
    MjI2Y2RkMTJkMzBhMWU4ZWM4OGM1ZmRkZWU2MDcwZDg0YTI1MGZjMQ==

COCOAPODS: #{Pod::VERSION}
      LOCKFILE
    end

    def podfile
      Pod::Podfile.new do
        platform :ios
        pod 'BananaLib', '~>1.0'
      end
    end

    def specs
      specs = [
        Pod::Specification.from_file(fixture('banana-lib/BananaLib.podspec')),
        Pod::Specification.new do |s|
          s.name = "monkey"
          s.version = "1.0.8"
        end
      ]
      specs.each { |s| s.activate_platform(:ios) }
      specs
    end

    def tmp_path
      temporary_directory + 'Podfile.lock'
    end

    it "loads from a hash" do
      lockfile = Pod::Lockfile.new(YAML.load(sample))
      lockfile.to_hash.should == YAML.load(sample)
    end

    it "loads from a file" do
      File.open(tmp_path, 'w') {|f| f.write(sample) }
      lockfile = Pod::Lockfile.from_file(tmp_path)
      lockfile.defined_in_file.should == tmp_path
      lockfile.to_hash.should == YAML.load(sample)
    end

    it "can be generated from a Podfile and a list of Specifications" do
      lockfile = Pod::Lockfile.generate(podfile, specs)
      lockfile.to_hash.should == YAML.load(sample)
    end

    before do
      @lockfile = Pod::Lockfile.generate(podfile, specs)
    end

    it "generates a valid YAML representation" do
      YAML.load(@lockfile.to_yaml).should == YAML.load(sample)
    end

    it "generates a valid Dictionary representation" do
      @lockfile.to_hash.should == YAML.load(sample)
    end

    it "returns the list of the installed pods" do
      @lockfile.pods_names.should == %w| BananaLib monkey |
    end

    it "returns the versions of the installed pods" do
      @lockfile.pods_versions.should == {
        "BananaLib" => Pod::Version.new("1.0"),
        "monkey" => Pod::Version.new("1.0.8")
      }
    end

    it "serializes correctly `:head' dependencies" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BananaLib', :head
      end
      specs = [
        Pod::Specification.new do |s|
          s.name = "BananaLib"
          s.version = "1.0"
        end,
        Pod::Specification.new do |s|
          s.name = "monkey"
          s.version = "1.0.8"
        end
      ]
      specs.each { |s| s.activate_platform(:ios) }
      lockfile = Pod::Lockfile.generate(podfile, specs)
      lockfile.to_hash["DEPENDENCIES"][0].should == "BananaLib (HEAD)"
    end

    it "serializes correctly external dependencies" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BananaLib', { :git => "www.example.com", :tag => '1.0' }
      end
      specs = [
        Pod::Specification.new do |s|
          s.name = "BananaLib"
          s.version = "1.0"
        end,
        Pod::Specification.new do |s|
          s.name = "monkey"
          s.version = "1.0.8"
        end
      ]
      specs.each { |s| s.activate_platform(:ios) }
      lockfile = Pod::Lockfile.generate(podfile, specs)
      lockfile.to_hash["DEPENDENCIES"][0].should == "BananaLib (from `www.example.com', tag `1.0')"
      lockfile.to_hash["EXTERNAL SOURCES"]["BananaLib"].should == { :git => "www.example.com", :tag => '1.0' }
    end

    it "creates a dependency from a string" do
      d = @lockfile.dependency_from_string("BananaLib (1.0)")
      d.name.should == "BananaLib"
      d.requirement.should =~ Pod::Version.new("1.0")
      d.head.should.be.nil
      d.external_source.should.be.nil
    end

    it "creates a head dependency from a string" do
      d = @lockfile.dependency_from_string("BananaLib (HEAD)")
      d.name.should == "BananaLib"
      d.requirement.should.be.none?
      d.head.should.be.true
      d.external_source.should.be.nil
    end

    it "creates an external dependency from a string" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BananaLib', { :git => "www.example.com", :tag => '1.0' }
      end
      lockfile = Pod::Lockfile.generate(podfile, [])
      d = lockfile.dependency_from_string("BananaLib (from `www.example.com', tag `1.0')")
      d.name.should == "BananaLib"
      d.requirement.should.be.none?
      d.external?.should.be.true
      d.external_source.description.should == "from `www.example.com', tag `1.0'"
    end
  end

  describe "Concerning initialization from a file" do
    extend SpecHelper::TemporaryDirectory

    it "returns nil if it can't find the initialization file" do
      lockfile = Pod::Lockfile.from_file(temporary_directory + 'Podfile.lock_not_existing')
      lockfile.should == nil
    end
  end

  describe "Concerning the identification of changes in the Podfile" do
    before do
      @podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
        pod 'JSONKit'
      end
      @specs = [
        Pod::Specification.new do |s|
          s.name = "BlocksKit"
          s.version = "1.0.0"
        end,
        Pod::Specification.new do |s|
          s.name = "JSONKit"
          s.version = "1.4"
        end ]
        @specs.each { |s| s.activate_platform(:ios) }
        @lockfile = Pod::Lockfile.generate(@podfile, @specs)
    end

    it "detects an added Pod" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
        pod 'JSONKit'
        pod 'TTTAttributedLabel'
      end
      @lockfile.detect_changes_with_podfile(podfile).should == {
        :changed=>[],
        :removed=>[],
        :unchanged=>["BlocksKit", "JSONKit"],
        :added=>["TTTAttributedLabel"]
      }
    end

    it "detects an removed Pod" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
      end
      @lockfile.detect_changes_with_podfile(podfile).should == {
        :changed=>[],
        :removed=>["JSONKit"],
        :unchanged=>["BlocksKit"],
        :added=>[]
      }
    end

    it "detects Pods whose version changed" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
        pod 'JSONKit', "> 1.4"
      end
      @lockfile.detect_changes_with_podfile(podfile).should == {
        :changed=>["JSONKit"],
        :removed=>[],
        :unchanged=>["BlocksKit"],
        :added=>[]
      }
    end

    it "it doesn't mark a changed Pods whose version changed but is still compatible with the Podfile" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
        pod 'JSONKit', "> 1.0"
      end
      @lockfile.detect_changes_with_podfile(podfile).should == {
        :changed=>[],
        :removed=>[],
        :unchanged=>["BlocksKit", "JSONKit"],
        :added=>[]
      }
    end

    it "detects Pods whose external source changed" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
        pod 'JSONKit', :git => "example1.com"
      end
      @lockfile.detect_changes_with_podfile(podfile).should == {
        :changed=>["JSONKit"],
        :removed=>[],
        :unchanged=>["BlocksKit"],
        :added=>[]
      }
      @lockfile = Pod::Lockfile.generate(podfile, @specs)
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
        pod 'JSONKit', :git => "example2.com"
      end
      @lockfile.detect_changes_with_podfile(podfile).should == {
        :changed=>["JSONKit"],
        :removed=>[],
        :unchanged=>["BlocksKit"],
        :added=>[]
      }
    end

    it "detects Pods whose head state changed" do
      podfile = Pod::Podfile.new do
        platform :ios
        pod 'BlocksKit'
        pod 'JSONKit', :head
      end
      @lockfile.detect_changes_with_podfile(podfile).should == {
        :changed=>["JSONKit"],
        :removed=>[],
        :unchanged=>["BlocksKit"],
        :added=>[]
      }
      @specs = [
        Pod::Specification.new do |s|
          s.name = "BlocksKit"
          s.version = "1.0.0"
        end,
        Pod::Specification.new do |s|
          s.name = "JSONKit"
          s.version = "1.4"
          s.version.head = true
        end ]
        @specs.each { |s| s.activate_platform(:ios) }
        @lockfile = Pod::Lockfile.generate(podfile, @specs)
        podfile = Pod::Podfile.new do
          platform :ios
          pod 'BlocksKit'
          pod 'JSONKit'
        end

        @lockfile.detect_changes_with_podfile(podfile).should == {
          :changed=>["JSONKit"],
          :removed=>[],
          :unchanged=>["BlocksKit"],
          :added=>[]
        }
    end
  end
end
