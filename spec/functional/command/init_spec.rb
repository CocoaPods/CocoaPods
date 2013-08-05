require File.expand_path('../../../spec_helper', __FILE__)

require 'xcodeproj'

module Pod

  describe Command::Init do

    it "complains if project does not exist" do
      lambda { run_command('init') }.should.raise Informative
      lambda { run_command('init', 'foo.xcodeproj') }.should.raise CLAide::Help
    end

    it "complains if wrong parameters" do
      lambda { run_command('too', 'many') }.should.raise CLAide::Help
    end

    it "complains if more than one project exists and none is specified" do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
        Xcodeproj::Project.new.save_as(temporary_directory + 'test2.xcodeproj')
        lambda { run_command('init') }.should.raise Informative
      end
    end

    it "complains if a Podfile already exists" do
      Dir.chdir(temporary_directory) do
        (Pathname.pwd + 'Podfile').open('w') { |f| f << "pod 'AFNetworking'" }
        Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
        lambda { run_command('init') }.should.raise Informative
      end
    end

    it "creates a Podfile for a project in current directory" do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
        run_command('init')
        Pathname.new(temporary_directory + 'Podfile').exist?.should == true
      end
    end

    it "creates a Podfile for a specified project" do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new.save_as(temporary_directory + 'test1.xcodeproj')
        Xcodeproj::Project.new.save_as(temporary_directory + 'test2.xcodeproj')
        run_command('init', 'test2.xcodeproj')
        Pathname.new(temporary_directory + 'Podfile').exist?.should == true
        config.podfile.nil?.should == false
      end
    end

    it "creates a Podfile with targets from the project" do
      Dir.chdir(temporary_directory) do
        project = Xcodeproj::Project.new
        target1 = project.new_target(:application, "AppA", :ios)
        target2 = project.new_target(:application, "AppB", :ios)
        project.save_as(temporary_directory + 'test.xcodeproj')

        run_command('init')

        config.podfile.nil?.should == false
        config.podfile.target_definitions.length.should == project.targets.length + 1
        config.podfile.target_definitions["AppA"].nil?.should == false
        config.podfile.target_definitions["AppB"].nil?.should == false
      end
    end

    it "includes default pods in a Podfile" do
      Dir.chdir(temporary_directory) do
        tmp_templates_dir = Pathname.pwd + 'templates_dir'
        tmp_templates_dir.mkpath
        config.stubs(:templates_dir).returns(tmp_templates_dir)

        open(config.default_podfile_path, 'w') { |f| f << "pod 'AFNetworking'" }

        Xcodeproj::Project.new.save_as(temporary_directory + 'test.xcodeproj')

        run_command('init')

        config.podfile.nil?.should == false
        config.podfile.dependencies.length.should == 1
        config.podfile.dependencies.first.name.should == "AFNetworking"
      end
    end

    it "includes default test pods in test targets in a Podfile" do
      Dir.chdir(temporary_directory) do
        tmp_templates_dir = Pathname.pwd + 'templates_dir'
        tmp_templates_dir.mkpath
        config.stubs(:templates_dir).returns(tmp_templates_dir)

        open(config.default_test_podfile_path, 'w') { |f| f << "pod 'Kiwi'" }

        project = Xcodeproj::Project.new
        project.new_target(:application, "AppTests", :ios)
        project.save_as(temporary_directory + 'test.xcodeproj')

        run_command('init')

        config.podfile.nil?.should == false
        config.podfile.dependencies.length.should == 1
        config.podfile.dependencies.first.name.should == "Kiwi"
      end
    end

    it "does not include default test pods if there are no test targets" do
      Dir.chdir(temporary_directory) do
        tmp_templates_dir = Pathname.pwd + 'templates_dir'
        tmp_templates_dir.mkpath
        config.stubs(:templates_dir).returns(tmp_templates_dir)

        open(config.default_test_podfile_path, 'w') { |f| f << "pod 'Kiwi'" }

        project = Xcodeproj::Project.new
        project.new_target(:application, "App", :ios)
        project.save_as(temporary_directory + 'test.xcodeproj')

        run_command('init')

        config.podfile.nil?.should == false
        config.podfile.dependencies.length.should == 0
      end
    end

  end
end
