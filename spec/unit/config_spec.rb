require File.expand_path('../../spec_helper', __FILE__)

module Pod

  describe Config do
    before do
      Config.instance = nil
    end

    describe "In general" do
      it "returns the singleton config instance" do
        config.should.be.instance_of Config
      end

      it "returns the path to the spec-repos dir" do
        config.repos_dir.should == Pathname.new("~/.cocoapods").expand_path
      end
    end

    describe "Concerning a user's project, which is expected in the current working directory" do

      before do
        config.installation_root = temporary_directory
      end

      it "returns the path to the project root" do
        config.installation_root.should == temporary_directory
      end

      it "returns the path to the project Podfile if it exists" do
        (temporary_directory + 'Podfile').open('w') { |f| f << '# Yo' }
        config.podfile_path.should == temporary_directory + 'Podfile'
      end

      it "returns the path to the project Podfile if specified with the extension" do
        (temporary_directory + 'CocoaPods.podfile').open('w') { |f| f << '# Yo' }
        config.podfile_path.should == temporary_directory + 'CocoaPods.podfile'
      end

      it "returns the path to the Pods directory that holds the dependencies" do
        config.sandbox_root.should == temporary_directory + 'Pods'
      end
    end

    describe "Concerning default settings" do

      before do
        Config.any_instance.stubs(:user_settings_file).returns(Pathname.new('not_found'))
      end

      it "prints out normal information" do
        config.should.not.be.silent
      end

      it "does not print verbose information" do
        config.should.not.be.verbose
      end

      it "cleans SCM dirs in dependency checkouts" do
        config.should.clean
      end
    end

    describe "Private helpers" do

      it "returns the path of the user settings file" do
        config.user_settings_file.should == Pathname.new("~/.cocoapods/config.yaml").expand_path
      end

      it "returns the path of the user settings file" do
        config.user_settings_file.should == Pathname.new("~/.cocoapods/config.yaml").expand_path
      end

    end
  end
end
