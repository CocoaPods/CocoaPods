require File.expand_path('../../../spec_helper', __FILE__)

require 'xcodeproj'

module Pod

  describe Command::Init do

    it "complains if project does not exist" do
      lambda { run_command('init') }.should.raise CLAide::Help
      lambda { run_command('init', 'foo.xcodeproj') }.should.raise CLAide::Help
    end

    it "complains if wrong parameters" do
      lambda { run_command('too', 'many') }.should.raise CLAide::Help
    end

    it "complains if more than one project exists and none is specified" do
      pwd = Dir.pwd
      Dir.chdir(temporary_directory)

      Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
      Xcodeproj::Project.new.save_as(temporary_directory + 'test2.xcodeproj')
      lambda { run_command('init') }.should.raise CLAide::Help

      Dir.chdir(pwd)
    end

    it "complains if a Podfile already exists" do
      pwd = Dir.pwd
      Dir.chdir(temporary_directory)

      (Pathname.pwd + 'Podfile').open('w') { |f| f << "pod 'AFNetworking'" }
      Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
      lambda { run_command('init') }.should.raise CLAide::Help

      Dir.chdir(pwd)
    end

    it "creates a Podfile for a project in current directory" do
      pwd = Dir.pwd
      Dir.chdir(temporary_directory)

      Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
      run_command('init')
      Pathname.new(temporary_directory + 'Podfile').exist?.should == true

      Dir.chdir(pwd)
    end

    it "creates a Podfile for a specified project" do
      pwd = Dir.pwd
      Dir.chdir(temporary_directory)

      Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
      Xcodeproj::Project.new.save_as(temporary_directory + 'test2.xcodeproj')
      run_command('init', 'test2.xcodeproj')
      Pathname.new(temporary_directory + 'Podfile').exist?.should == true
      config.podfile.nil?.should == false

      Dir.chdir(pwd)
    end

  end
end
