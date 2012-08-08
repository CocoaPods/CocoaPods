require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Lockfile" do
  extend SpecHelper::TemporaryDirectory

  def sample
    text = <<-LOCKFILE.strip_heredoc
      ---
      PODS:
      - BananaLib (1.0):
        - monkey (< 1.0.9, ~> 1.0.1)
      - monkey (1.0.8)
      DEPENDENCIES:
      - BananaLib (~> 1.0)
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

  it "loads from a file" do
    File.open(tmp_path, 'w') {|f| f.write(sample) }
    lockfile = Pod::Lockfile.from_file(tmp_path)
    lockfile.defined_in_file.should == tmp_path
    lockfile.to_yaml.should == sample
  end

  before do
    @lockfile = Pod::Lockfile.create(tmp_path, podfile, specs)
  end

  it "generates a valid YAML representation" do
    @lockfile.to_yaml.should == sample
  end

  it "generates a valid Dictionary representation" do
    @lockfile.to_dict.should == YAML.load(sample)
  end

  it "returns the Podfile dependencies" do
    @lockfile.podfile_dependencies.should == [
      Pod::Dependency.new("BananaLib", "~> 1.0")
    ]
  end

  it "returns the dependencies for the installed pods" do
    @lockfile.installed_dependencies.should == [
      Pod::Dependency.new("BananaLib", "= 1.0"),
      Pod::Dependency.new("monkey", "= 1.0.8")
    ]
  end

  it "can check if it is compatible with a file" do
    File.open(tmp_path, 'w') {|f| f.write(sample.gsub("COCOAPODS: #{Pod::VERSION}", "")) }
    lockfile = Pod::Lockfile.from_file(tmp_path)
    lockfile.to_dict.should == nil
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
    lockfile = Pod::Lockfile.create(tmp_path, podfile, specs)
    lockfile.to_dict["DEPENDENCIES"][0].should == "BananaLib [HEAD]"
  end

  it "serializes correctly external dependencies" do
    podfile = Pod::Podfile.new do
      platform :ios
      pod 'BananaLib', :git => "www.example.com"
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
    lockfile = Pod::Lockfile.create(tmp_path, podfile, specs)
    lockfile.to_dict["DEPENDENCIES"][0].should == "BananaLib (from `www.example.com')"
  end

  xit "reads `:heads' dependencies correctly" do
  end

  xit "reads external dependencies dependencies correctly" do
  end
end
