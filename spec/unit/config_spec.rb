require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Config" do
  before do
    Pod::Config.instance = nil
  end

  it "returns the singleton config instance" do
    config.should.be.instance_of Pod::Config
  end

  it "returns the path to the spec-repos dir" do
    config.repos_dir.should == Pathname.new("~/.cocoapods").expand_path
  end

  describe "concerning a user's project, which is expected in the current working directory" do
    extend SpecHelper::TemporaryDirectory

    it "returns the path to the project root" do
      config.project_root = nil
      config.project_root.should == Pathname.pwd
      config.project_root = temporary_directory
    end

    it "returns the path to the project Podfile if it exists" do
      (temporary_directory + 'Podfile').open('w') { |f| f << '# Yo' }
      Dir.chdir(temporary_directory) do
        config.project_podfile.should == Pathname.pwd + 'Podfile'
      end
    end

    it "returns the path to the project Podfile if specified with the extension" do
      (temporary_directory + 'CocoaPods.podfile').open('w') { |f| f << '# Yo' }
      Dir.chdir(temporary_directory) do
        config.project_podfile.should == Pathname.pwd + 'CocoaPods.podfile'
      end
    end

    it "returns the path to the Pods directory that holds the dependencies" do
      config.project_pods_root.should == Pathname.pwd + 'Pods'
    end
  end

  describe "concerning default settings" do
    it "prints out normal information" do
      config.should.not.be.silent
    end

    it "does not print vebose information" do
      config.should.not.be.verbose
    end

    it "cleans SCM dirs in dependency checkouts" do
      config.should.clean
    end
  end
end
