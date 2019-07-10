require File.expand_path('../../../spec_helper', __FILE__)

require 'xcodeproj'

module Pod
  describe Command::Init do
    it 'complains if project does not exist' do
      lambda { run_command('init') }.should.raise Informative
      lambda { run_command('init', 'foo.xcodeproj') }.should.raise CLAide::Help
    end

    it 'complains if wrong parameters' do
      lambda { run_command('too', 'many') }.should.raise CLAide::Help
    end

    it 'complains if more than one project exists and none is specified' do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new(temporary_directory + 'test2.xcodeproj').save
        Xcodeproj::Project.new(temporary_directory + 'test1.xcodeproj').save
        lambda { run_command('init') }.should.raise Informative
      end
    end

    it 'complains if a Podfile already exists' do
      Dir.chdir(temporary_directory) do
        (Pathname.pwd + 'Podfile').open('w') { |f| f << "pod 'AFNetworking'" }
        Xcodeproj::Project.new(temporary_directory + 'test1.xcodeproj').save
        lambda { run_command('init') }.should.raise Informative
      end
    end

    it 'creates a Podfile for a project in current directory' do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new(temporary_directory + 'test1.xcodeproj').save
        run_command('init')
        Pathname.new(temporary_directory + 'Podfile').exist?.should == true
      end
    end

    it 'creates a Podfile for a specified project' do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new(temporary_directory + 'test1.xcodeproj').save
        Xcodeproj::Project.new(temporary_directory + 'test2.xcodeproj').save
        run_command('init', 'test2.xcodeproj')
        Pathname.new(temporary_directory + 'Podfile').exist?.should == true
        config.podfile.nil?.should == false
      end
    end

    it 'creates a Podfile with targets from the project' do
      Dir.chdir(temporary_directory) do
        project = Xcodeproj::Project.new(temporary_directory + 'test.xcodeproj')
        project.new_target(:application, 'AppA', :ios)
        project.new_target(:application, 'AppB', :ios)
        project.new_target(:application, "App'C", :ios)
        project.new_aggregate_target('Aggregate')
        project.save

        run_command('init')

        config.podfile.should.not.be.nil
        config.podfile.target_definitions.length.should == project.targets.length
        config.podfile.target_definitions['AppA'].should.not.be.nil
        config.podfile.target_definitions['AppB'].should.not.be.nil
        config.podfile.target_definitions["App'C"].should.not.be.nil
        config.podfile.target_definitions['Aggregate'].should.be.nil
      end
    end

    it 'includes default pods in a Podfile' do
      Dir.chdir(temporary_directory) do
        tmp_templates_dir = Pathname.pwd + 'templates_dir'
        tmp_templates_dir.mkpath
        config.stubs(:templates_dir).returns(tmp_templates_dir)

        open(config.default_podfile_path, 'w') { |f| f << "pod 'AFNetworking'" }

        project = Xcodeproj::Project.new(temporary_directory + 'test.xcodeproj')
        project.new_target(:application, 'AppA', :ios)
        project.save

        run_command('init')

        dependencies = config.podfile.target_definitions['AppA'].dependencies
        dependencies.map(&:name).should == ['AFNetworking']
      end
    end

    it 'handles hooking up multiple test targets based on an xcodeproj project' do
      Dir.chdir(temporary_directory) do
        project = Xcodeproj::Project.new(temporary_directory + 'test.xcodeproj')
        project.new_target(:application, 'App', :ios)
        project.new_target(:unit_test_bundle, 'AppTests', :ios)
        project.new_target(:ui_test_bundle, 'AppFeatureTests', :ios)
        project.new_target(:application, 'Swifty App', :osx, nil, nil, :swift).add_file_references([project.new_file('foo.swift')])
        project.save

        run_command('init')

        expected_podfile = <<-RUBY.strip_heredoc
          # Uncomment the next line to define a global platform for your project
          # platform :ios, '9.0'

          target 'App' do
            # Comment the next line if you don't want to use dynamic frameworks
            use_frameworks!

            # Pods for App

            target 'AppFeatureTests' do
              # Pods for testing
            end

            target 'AppTests' do
              inherit! :search_paths
              # Pods for testing
            end

          end

          target 'Swifty App' do
            # Comment the next line if you don't want to use dynamic frameworks
            use_frameworks!

            # Pods for Swifty App

          end
        RUBY

        File.read('Podfile').should == expected_podfile
      end
    end

    it 'embeds pods into test targets since their parent requires it' do
      Dir.chdir(temporary_directory) do
        project = Xcodeproj::Project.new(temporary_directory + 'test.xcodeproj')
        project.new_target(:application, 'App', :ios)
        project.new_target(:framework, 'Framework', :ios)
        project.new_target(:static_library, 'Library', :ios)
        project.new_target(:unit_test_bundle, 'AppTests', :ios)
        project.new_target(:ui_test_bundle, 'AppUITests', :ios)
        project.new_target(:unit_test_bundle, 'FrameworkTests', :ios)
        project.new_target(:unit_test_bundle, 'LibraryTests', :ios)
        project.save

        run_command('init')

        expected_podfile = <<-RUBY.strip_heredoc
          # Uncomment the next line to define a global platform for your project
          # platform :ios, '9.0'

          target 'App' do
            # Comment the next line if you don't want to use dynamic frameworks
            use_frameworks!

            # Pods for App

            target 'AppTests' do
              inherit! :search_paths
              # Pods for testing
            end

            target 'AppUITests' do
              # Pods for testing
            end

          end

          target 'Framework' do
            # Comment the next line if you don't want to use dynamic frameworks
            use_frameworks!

            # Pods for Framework

            target 'FrameworkTests' do
              # Pods for testing
            end

          end

          target 'Library' do
            # Comment the next line if you don't want to use dynamic frameworks
            use_frameworks!

            # Pods for Library

            target 'LibraryTests' do
              # Pods for testing
            end

          end
        RUBY

        File.read('Podfile').should == expected_podfile
      end
    end

    it 'includes default test pods in test targets in a Podfile' do
      Dir.chdir(temporary_directory) do
        tmp_templates_dir = Pathname.pwd + 'templates_dir'
        tmp_templates_dir.mkpath
        config.stubs(:templates_dir).returns(tmp_templates_dir)

        open(config.default_test_podfile_path, 'w') { |f| f << "pod 'Kiwi'" }

        project = Xcodeproj::Project.new(temporary_directory + 'test.xcodeproj')
        project.new_target(:application, 'App', :ios)
        project.new_target(:unit_test_bundle, 'AppTests', :ios)
        project.save

        run_command('init')

        dependencies = config.podfile.target_definitions['AppTests'].dependencies
        dependencies.map(&:name).should == ['Kiwi']
      end
    end

    it 'does not treat non-test targets as test targets' do
      Dir.chdir(temporary_directory) do
        tmp_templates_dir = Pathname.pwd + 'templates_dir'
        tmp_templates_dir.mkpath
        config.stubs(:templates_dir).returns(tmp_templates_dir)

        open(config.default_test_podfile_path, 'w') { |f| f << "pod 'Kiwi'" }

        project = Xcodeproj::Project.new(temporary_directory + 'test.xcodeproj')
        project.new_target(:application, 'Test', :ios)
        project.new_target(:application, 'Test Test Test', :ios)
        project.save

        run_command('init')

        config.podfile.target_definitions['Test'].dependencies.should.be.empty
        config.podfile.target_definitions['Test Test Test'].dependencies.should.be.empty
      end
    end

    it 'does not include default test pods if there are no test targets' do
      Dir.chdir(temporary_directory) do
        tmp_templates_dir = Pathname.pwd + 'templates_dir'
        tmp_templates_dir.mkpath
        config.stubs(:templates_dir).returns(tmp_templates_dir)

        open(config.default_test_podfile_path, 'w') { |f| f << "pod 'Kiwi'" }

        project = Xcodeproj::Project.new(temporary_directory + 'test.xcodeproj')
        project.new_target(:application, 'App', :ios)
        project.save

        run_command('init')

        config.podfile.nil?.should == false
        config.podfile.dependencies.length.should == 0
      end
    end

    it 'saves xcode project file in Podfile if one was supplied' do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new(temporary_directory + 'test1.xcodeproj').save
        Xcodeproj::Project.new(temporary_directory + 'Project.xcodeproj').save

        run_command('init', 'Project.xcodeproj')

        target_definition = config.podfile.target_definitions.values.first
        target_definition.user_project_path.should == 'Project.xcodeproj'
      end
    end

    it "doesn't save xcode project file in Podfile if one wasn't supplied" do
      Dir.chdir(temporary_directory) do
        Xcodeproj::Project.new(temporary_directory + 'Project.xcodeproj').save

        run_command('init')

        target_definition = config.podfile.target_definitions.values.first
        target_definition.user_project_path.should.nil?
      end
    end
  end
end
