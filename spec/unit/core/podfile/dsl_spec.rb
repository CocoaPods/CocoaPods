require File.expand_path('../../spec_helper', __FILE__)

module Pod
  describe Podfile::DSL do
    describe 'Dependencies' do
      it 'adds dependencies' do
        podfile = Podfile.new do
          pod 'ASIHTTPRequest'
          pod 'SSZipArchive', '>= 0.1'
        end
        podfile.dependencies.size.should == 2
        podfile.dependencies.find { |d| d.root_name == 'ASIHTTPRequest' }.should == Dependency.new('ASIHTTPRequest')
        podfile.dependencies.find { |d| d.root_name == 'SSZipArchive' }.should == Dependency.new('SSZipArchive', '>= 0.1')
      end

      describe 'whitelisting pods per configuration' do
        it 'white-list dependencies on all build configuration by default' do
          podfile = Podfile.new do
            pod 'PonyDebugger'
          end

          target = podfile.target_definitions['Pods']
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Release').should.be.true
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Debug').should.be.true
        end

        it 'allows to white-list a dependency on multiple build configuration' do
          podfile = Podfile.new do
            pod 'PonyDebugger', :configurations => ['Release', 'App Store']
          end

          target = podfile.target_definitions['Pods']
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Release').should.be.true
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'App Store').should.be.true
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Debug').should.be.false
        end

        it 'allows to white-list a dependency on a build configuration' do
          podfile = Podfile.new do
            pod 'PonyDebugger', :configuration => 'Release'
          end

          target = podfile.target_definitions['Pods']
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Release').should.be.true
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Debug').should.be.false
        end

        it 'allows to white-list a dependency on a build configuration in a target block' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :configuration => 'Release'
            end
          end

          target = podfile.target_definitions['App']
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Release').should.be.true
          target.pod_whitelisted_for_configuration?('PonyDebugger', 'Debug').should.be.false
        end
      end

      describe 'inhibiting warnings' do
        it 'does not inhibit warnings on dependencies by default' do
          podfile = Podfile.new do
            pod 'PonyDebugger'
          end

          target = podfile.target_definitions['Pods']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.false
        end

        it 'raises if :inhibit_warnings value is not a boolean' do
          should.raise ArgumentError do
            podfile = Podfile.new do
              pod 'PonyDebugger', :inhibit_warnings => 'true'
            end
            target = podfile.target_definitions['Pods']
            target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
          end.message.should.match /should be a boolean/
        end

        it 'allows inhibiting warnings on a single dependency' do
          podfile = Podfile.new do
            pod 'PonyDebugger', :inhibit_warnings => true
          end

          target = podfile.target_definitions['Pods']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
        end

        it 'allows not inhibiting warnings on a single dependency' do
          podfile = Podfile.new do
            inhibit_all_warnings!
            pod 'PonyDebugger', :inhibit_warnings => false
          end

          target = podfile.target_definitions['Pods']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.false
        end

        it 'allows inhibiting warnings on a single dependency in a target block' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :inhibit_warnings => true
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
        end

        it 'allows not inhibiting warnings on a single dependency in a target block' do
          podfile = Podfile.new do
            inhibit_all_warnings!
            target 'App' do
              pod 'PonyDebugger', :inhibit_warnings => false
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.false
        end

        it 'allows inhibiting warnings on a single dependency in a target block with inheritance' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :inhibit_warnings => true
              target 'Inherited' do
                pod 'PonyDebugger', :inhibit_warnings => false
              end
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
        end

        it 'allows inhibiting in parent and not inhibiting in child on a single dependency' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :inhibit_warnings => true
              target 'Inherited' do
                pod 'PonyDebugger', :inhibit_warnings => false
              end
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true

          target = podfile.target_definitions['Inherited']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.false
        end

        it 'allows not inhibiting in parent and inhibiting in child on a single dependency' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :inhibit_warnings => false
              target 'Inherited' do
                pod 'PonyDebugger', :inhibit_warnings => true
              end
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.false

          target = podfile.target_definitions['Inherited']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
        end

        it 'allows not inhibiting a single dependency in parent and inhibiting all dependencies in child' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :inhibit_warnings => false
              target 'Inherited' do
                inhibit_all_warnings!
                pod 'PonyDebugger'
              end
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.false

          target = podfile.target_definitions['Inherited']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
        end

        it 'allows not inhibiting a single dependency in grandparent and inhibiting all dependencies in grandchild' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :inhibit_warnings => false
              target 'Inherited' do
                target 'InheritedLevelTwo' do
                  inhibit_all_warnings!
                  pod 'PonyDebugger'
                end
              end
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.false

          target = podfile.target_definitions['InheritedLevelTwo']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
        end

        it 'allows inhibiting all warnings in parent and child scopes' do
          podfile = Podfile.new do
            inhibit_all_warnings!
            target 'App' do
              pod 'PonyDebugger'
              inhibit_all_warnings!
              target 'Inherited' do
                inhibit_all_warnings!
              end
            end
          end

          target = podfile.target_definitions['App']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true

          target = podfile.target_definitions['Inherited']
          target.inhibits_warnings_for_pod?('PonyDebugger').should.be.true
        end
      end

      describe 'project names' do
        it 'sets the project name for a given pod' do
          podfile = Podfile.new do
            pod 'PonyDebugger', :project_name => 'PonyProject'
          end

          target = podfile.target_definitions['Pods']
          target.project_name_for_pod('PonyDebugger').should == 'PonyProject'
        end
      end

      describe 'modular headers' do
        it 'does not have modular headers by default' do
          podfile = Podfile.new do
            pod 'PonyDebugger'
          end

          target = podfile.target_definitions['Pods']
          target.build_pod_as_module?('PonyDebugger').should.be.false
        end

        it 'raises if :modular_headers value is not a boolean' do
          should.raise ArgumentError do
            podfile = Podfile.new do
              pod 'PonyDebugger', :modular_headers => 'true'
            end
            target = podfile.target_definitions['Pods']
            target.build_pod_as_module?('PonyDebugger').should.be.true
          end.message.should.match /should be a boolean/
        end

        it 'allows modular headers on a single dependency' do
          podfile = Podfile.new do
            pod 'PonyDebugger', :modular_headers => true
          end

          target = podfile.target_definitions['Pods']
          target.build_pod_as_module?('PonyDebugger').should.be.true
        end

        it 'allows not modular headers on a single dependency' do
          podfile = Podfile.new do
            use_modular_headers!
            pod 'PonyDebugger', :modular_headers => false
          end

          target = podfile.target_definitions['Pods']
          target.build_pod_as_module?('PonyDebugger').should.be.false
        end

        it 'allows modular headers on a single dependency in a target block' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :modular_headers => true
            end
          end

          target = podfile.target_definitions['App']
          target.build_pod_as_module?('PonyDebugger').should.be.true
        end

        it 'allows not modular headers on a single dependency in a target block' do
          podfile = Podfile.new do
            use_modular_headers!
            target 'App' do
              pod 'PonyDebugger', :modular_headers => false
            end
          end

          target = podfile.target_definitions['App']
          target.build_pod_as_module?('PonyDebugger').should.be.false
        end

        it 'allows modular headers on a single dependency in a target block with inheritance' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :modular_headers => true
              target 'Inherited' do
                pod 'PonyDebugger', :modular_headers => false
              end
            end
          end

          target = podfile.target_definitions['App']
          target.build_pod_as_module?('PonyDebugger').should.be.true
        end

        it 'allows modular headers in parent and not using them in child on a single dependency' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :modular_headers => true
              target 'Inherited' do
                pod 'PonyDebugger', :modular_headers => false
              end
            end
          end

          target = podfile.target_definitions['App']
          target.build_pod_as_module?('PonyDebugger').should.be.true

          target = podfile.target_definitions['Inherited']
          target.build_pod_as_module?('PonyDebugger').should.be.false
        end

        it 'allows not using modular headers in parent and using modular headers in child on a single dependency' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :modular_headers => false
              target 'Inherited' do
                pod 'PonyDebugger', :modular_headers => true
              end
            end
          end

          target = podfile.target_definitions['App']
          target.build_pod_as_module?('PonyDebugger').should.be.false

          target = podfile.target_definitions['Inherited']
          target.build_pod_as_module?('PonyDebugger').should.be.true
        end

        it 'allows not using modular headers a single dependency in parent and using modular headers all dependencies in child' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :modular_headers => false
              target 'Inherited' do
                use_modular_headers!
                pod 'PonyDebugger'
              end
            end
          end

          target = podfile.target_definitions['App']
          target.build_pod_as_module?('PonyDebugger').should.be.false

          target = podfile.target_definitions['Inherited']
          target.build_pod_as_module?('PonyDebugger').should.be.true
        end

        it 'allows not using modular headers a single dependency in grandparent and using modular headers all dependencies in grandchild' do
          podfile = Podfile.new do
            target 'App' do
              pod 'PonyDebugger', :modular_headers => false
              target 'Inherited' do
                target 'InheritedLevelTwo' do
                  use_modular_headers!
                  pod 'PonyDebugger'
                end
              end
            end
          end

          target = podfile.target_definitions['App']
          target.build_pod_as_module?('PonyDebugger').should.be.false

          target = podfile.target_definitions['InheritedLevelTwo']
          target.build_pod_as_module?('PonyDebugger').should.be.true
        end
      end

      it 'allows specifying multiple subspecs' do
        podfile = Podfile.new do
          pod 'RestKit', '~> 0.24.0', :subspecs => %w(CoreData Networking), :configurations => %w(Release)
        end

        target = podfile.target_definitions['Pods']
        expected_dependencies = [
          Dependency.new('RestKit/CoreData', '~> 0.24.0'),
          Dependency.new('RestKit/Networking', '~> 0.24.0'),
        ]
        target.dependencies.sort_by(&:name).should == expected_dependencies
        target.pod_whitelisted_for_configuration?('RestKit', 'Release').should.be.true

        podfile = Podfile.new do
          pod 'RestKit/Subspec', :subspecs => %w(CoreData Networking/Subspec), :git => 'https://github.com/RestKit/RestKit.git'
        end

        target = podfile.target_definitions['Pods']
        expected_dependencies = [
          Dependency.new('RestKit/Subspec/CoreData', :git => 'https://github.com/RestKit/RestKit.git'),
          Dependency.new('RestKit/Subspec/Networking/Subspec', :git => 'https://github.com/RestKit/RestKit.git'),
        ]
        target.dependencies.sort_by(&:name).should == expected_dependencies
      end

      it 'raises if no name is specified for a Pod' do
        lambda do
          Podfile.new do
            pod
          end
        end.should.raise Podfile::StandardError
      end

      it 'raises if an inlide podspec is specified' do
        lambda do
          Podfile.new do
            pod do |s|
              s.name = 'mypod'
            end
          end
        end.should.raise Podfile::StandardError
      end

      it 'it can use use the dependencies of a podspec' do
        banalib_path = fixture('BananaLib.podspec').to_s
        podfile = Podfile.new(fixture('Podfile')) do
          platform :ios
          podspec :path => banalib_path
        end
        podfile.dependencies.map(&:name).should == %w(monkey AFNetworking SDWebImage)
      end

      it 'it can use use the dependencies of a podspec\'s subspec' do
        banalib_path = fixture('BananaLib.podspec').to_s
        podfile = Podfile.new(fixture('Podfile')) do
          platform :ios
          podspec :path => banalib_path, :subspec => 'GreenBanana'
        end
        podfile.dependencies.map(&:name).should == %w(monkey AFNetworking)
      end

      it 'allows specifying a child target definition' do
        podfile = Podfile.new do
          target :tests do
            pod 'OCMock'
          end
        end
        podfile.target_definitions[:tests].name.should == :tests
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Target configuration' do
      it 'allows specifying a platform' do
        podfile = Podfile.new do
          platform :ios, '6.0'
          target :osx_target do
            platform :osx, '10.8'
          end
        end
        podfile.target_definitions['Pods'].platform.should == Platform.new(:ios, '6.0')
        podfile.target_definitions[:osx_target].platform.should == Platform.new(:osx, '10.8')
      end

      it 'does not allow specifying a platform twice' do
        should.raise(Podfile::StandardError) do
          Podfile.new do
            platform :ios, '6.0'
            platform :ios, '9.0'
          end
        end.message.should == 'The target `Pods` already has a platform set.'
      end

      it 'allows specifying whether the target is exclusive' do
        podfile = Podfile.new do
          target 'Pods' do
            inherit!(:none)
          end
        end
        podfile.target_definitions['Pods'].should.be.exclusive
      end

      it 'is not exclusive by default' do
        podfile = Podfile.new do
          target 'Pods' do
          end
        end
        podfile.target_definitions['Pods'].should.not.be.exclusive
      end

      it 'allows specifying whether the target is abstract' do
        podfile = Podfile.new do
          target 'App' do
            abstract!
          end
        end
        podfile.target_definitions['App'].should.be.abstract
      end

      it 'is not abstract by default' do
        podfile = Podfile.new do
          target 'App' do
          end
        end
        podfile.target_definitions['App'].should.not.be.abstract
      end

      it 'allows specifying an abstract target' do
        podfile = Podfile.new do
          abstract_target 'App' do
          end
        end
        podfile.target_definitions['App'].should.be.abstract
      end

      describe 'inheritance' do
        it 'allows specifying the inheritance mode for a target' do
          modes = %w(search_paths complete none)
          modes.each do |mode|
            podfile = Podfile.new do
              target 'App' do
                inherit! mode
              end
            end
            podfile.target_definitions['App'].inheritance.should == mode
          end
        end

        it 'raises when specifying an unknown mode' do
          should.raise(Informative) do
            Podfile.new do
              target 'App' do
                inherit! 'foo'
              end
            end
          end.message.should == 'Unrecognized inheritance option `foo` specified for target `App`.'
        end
      end

      it 'raises if unrecognized keys are passed during the initialization of a target' do
        should.raise Informative do
          Podfile.new do
            target 'Pods', :unrecognized => true do
            end
          end
        end
      end

      it 'allows specifying the user Xcode project for a Target definition' do
        podfile = Podfile.new { project 'App.xcodeproj' }
        podfile.target_definitions['Pods'].user_project_path.should == 'App.xcodeproj'
      end

      it 'allows specifying the build configurations of a user project' do
        podfile = Podfile.new do
          project 'App.xcodeproj', 'Mac App Store' => :release, 'Test' => :debug
        end
        podfile.target_definitions['Pods'].build_configurations.should == {
          'Mac App Store' => :release, 'Test' => :debug
        }
      end

      it 'allows to inhibit all the warnings of a Target definition' do
        podfile = Podfile.new do
          pod 'ObjectiveRecord'
          inhibit_all_warnings!
        end
        podfile.target_definitions['Pods'].inhibits_warnings_for_pod?('ObjectiveRecord').should.be.true
      end

      it 'defaults to not use frameworks for a Target definition' do
        podfile = Podfile.new { pod 'ObjectiveRecord' }
        podfile.target_definitions['Pods'].uses_frameworks?.should.be.false
      end

      it 'allows to use frameworks for a Target definition' do
        podfile = Podfile.new do
          pod 'ObjectiveRecord'
          use_frameworks!
        end
        podfile.target_definitions['Pods'].uses_frameworks?.should.be.true
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Workspace' do
      it 'specifies the Xcode workspace to use' do
        Podfile.new do
          workspace 'MyWorkspace.xcworkspace'
        end.workspace_path.should == 'MyWorkspace.xcworkspace'
      end

      it 'specifies that BridgeSupport metadata should be generated' do
        Podfile.new {}.should.not.generate_bridge_support
        Podfile.new { generate_bridge_support! }.should.generate_bridge_support
      end

      it 'specifies that ARC compatibility flag should be generated' do
        Podfile.new {}.should.not.set_arc_compatibility_flag
        Podfile.new { set_arc_compatibility_flag! }.should.set_arc_compatibility_flag
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Hooks' do
      it 'stores a block that will be called before integrating the targets' do
        yielded = nil
        Podfile.new do
          pre_install do |installer|
            yielded = installer
          end
        end.pre_install!(:an_installer)
        yielded.should == :an_installer
      end

      it 'stores a block that will be called with the Installer instance once installation is finished' do
        yielded = nil
        Podfile.new do
          post_install do |installer|
            yielded = installer
          end
        end.post_install!(:an_installer)
        yielded.should == :an_installer
      end

      it 'raises when post_install is called multiple times' do
        should.raise(Informative) do
          Podfile.new do
            target 'App' do
              post_install do |installer|
              end

              post_install do |installer|
              end
            end
          end
        end.message.should == 'Specifying multiple `post_install` hooks is unsupported.'
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Installation Method' do
      it 'allows specifying a custom installation method' do
        podfile = Podfile.new do
          install! 'method'
        end
        podfile.installation_method.should == ['method', {}]
      end

      it 'allows specifying a custom installation method with options' do
        podfile = Podfile.new do
          install! 'method', 'option' => 'value'
        end
        podfile.installation_method.should == ['method', { 'option' => 'value' }]
      end

      it 'raises when specifying an installation method outside of root' do
        should.raise(Informative) do
          Podfile.new do
            target 'App' do
              install! 'method'
            end
          end
        end.message.should == 'The installation method can only be set at the root level of the Podfile.'
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Deprecations' do
      it 'raises when using the #link_with method' do
        should.raise(Informative) do
          Podfile.new do
            link_with 'App'
          end
        end.message.should == 'The specification of `link_with` in the Podfile is now unsupported, please use target blocks instead.'
      end

      it 'warns when using the #xcodeproj method' do
        podfile = Podfile.new { xcodeproj 'App.xcodeproj', 'Test' => :debug }
        podfile.target_definitions['Pods'].user_project_path.should == 'App.xcodeproj'
        podfile.target_definitions['Pods'].build_configurations.should == { 'Test' => :debug }
        CoreUI.warnings.should == '`xcodeproj` was renamed to `project`. Please update your Podfile accordingly.'
      end
    end

    describe 'script phases' do
      it 'raises when adding a script phase to the root target definition' do
        should.raise(Informative) do
          Podfile.new do
            script_phase :name => 'PhaseName', :script => 'echo "Hello World"'
          end
        end.message.should == 'Script phases can only be added within target definitions.'
      end

      it 'raises when adding a script phase to an abstract target' do
        should.raise(Informative) do
          Podfile.new do
            abstract_target 'AbstractTarget' do
              script_phase :name => 'PhaseName', :script => 'echo "Hello World"'
            end
          end
        end.message.should == 'Script phases cannot be added to abstract targets.'
      end
    end

    #-------------------------------------------------------------------------#
  end
end
