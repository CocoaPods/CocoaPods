require File.expand_path('../../../spec_helper', __FILE__)

module Pod
  describe Podfile do
    describe 'In general' do
      it 'stores the path of the file it is loaded from' do
        podfile = Podfile.from_file(fixture('Podfile'))
        podfile.defined_in_file.should == fixture('Podfile')
      end

      it 'returns the string representation' do
        Podfile.new {}.to_s.should == 'Podfile'
      end

      it 'creates a default target definition if a block is provided' do
        podfile = Podfile.new {}
        podfile.root_target_definitions.count.should == 1
        podfile.root_target_definitions.first.name.should == 'Pods'
      end

      it 'names the default target definition as Pods' do
        podfile = Podfile.new {}
        podfile.root_target_definitions.first.name.should == 'Pods'
      end

      it 'is equatable' do
        Podfile.new.should == Podfile.new

        Podfile.from_file(fixture('Podfile')).should == Podfile.from_file(fixture('Podfile'))
        Podfile.from_file(fixture('Podfile')).should == Podfile.from_file(fixture('Podfile')).tap { |pf| pf.defined_in_file = Pathname('foo') }
        Podfile.from_file(fixture('Podfile')).should == Podfile.from_file(fixture('Podfile.yaml'))

        Podfile.from_file(fixture('Podfile')).should.not == Podfile.new
        Podfile.from_file(fixture('Podfile')).should.not == Podfile.from_ruby(fixture('Podfile'), fixture('Podfile').read.gsub(/pod '/, "pod 'A_"))
      end

      extend SpecHelper::TemporaryDirectory

      it 'includes the line of the podfile that generated an exception' do
        podfile_content = "\n# Comment\npod "
        podfile_file = temporary_directory + 'Podfile'
        File.open(podfile_file, 'w') { |f| f.write(podfile_content) }
        raised = false
        begin
          Podfile.from_file(podfile_file)
        rescue DSLError => e
          raised = true
          e.message.should.match %r{from .*/tmp/Podfile:3}
          e.message.should.match /requires a name/
          e.message.should.match /# Comment/
        end
        raised.should.be.true
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Working with a Podfile' do
      before do
        @podfile = Podfile.new do
          pod 'ASIHTTPRequest'
          pod 'JSONKit'
          target 'sub-target' do
            pod 'JSONKit'
            pod 'Reachability'
            pod 'SSZipArchive'
          end
        end
      end

      it 'returns the string representation' do
        @podfile.to_s.should == 'Podfile'
      end

      it 'returns the target definitions' do
        @podfile.target_definitions.count.should == 2
        @podfile.target_definitions['Pods'].name.should == 'Pods'
        @podfile.target_definitions['sub-target'].name.should == 'sub-target'
      end

      it 'indicates if the pre install hook was executed' do
        Podfile.new {}.pre_install!(:an_installer).should.be == false
        result = Podfile.new { pre_install { |_installer| } }.pre_install!(:an_installer)
        result.should.be == true
      end

      it 'returns all dependencies of all targets combined' do
        @podfile.dependencies.map(&:name).sort.should == %w(ASIHTTPRequest JSONKit Reachability SSZipArchive)
      end

      it 'indicates if the post install hook was executed' do
        Podfile.new {}.post_install!(:an_installer).should.be == false
        result = Podfile.new { post_install { |_installer| } }.post_install!(:an_installer)
        result.should.be == true
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Attributes' do
      it 'returns the workspace' do
        Podfile.new do
          workspace 'MyWorkspace.xcworkspace'
        end.workspace_path.should == 'MyWorkspace.xcworkspace'
      end

      it 'appends the extension to the specified workspaces if needed' do
        Podfile.new do
          workspace 'MyWorkspace'
        end.workspace_path.should == 'MyWorkspace.xcworkspace'
      end

      it 'returns whether the BridgeSupport metadata should be generated' do
        Podfile.new {}.should.not.generate_bridge_support
        Podfile.new { generate_bridge_support! }.should.generate_bridge_support
      end

      it 'returns whether the ARC compatibility flag should be set' do
        Podfile.new {}.should.not.set_arc_compatibility_flag
        Podfile.new { set_arc_compatibility_flag! }.should.set_arc_compatibility_flag
      end

      it 'returns the installation method' do
        name, options = Podfile.new {}.installation_method
        name.should == 'cocoapods'
        options.should == {}

        name, options = Podfile.new { install! 'install-method', :option1 => 'value1', 'option2' => false }.installation_method
        name.should == 'install-method'
        options.should == { :option1 => 'value1', 'option2' => false }
      end

      describe 'source' do
        it 'can have multiple sources' do
          Podfile.new do
            source 'new_repo_1'
            source 'new_repo_2'
          end.sources.size.should == 2

          Podfile.new do
            source 'new_repo_1'
            source 'new_repo_2'
            source 'master'
          end.sources.size.should == 3
        end
      end

      describe 'plugin' do
        it 'can have mutiple plugins' do
          Podfile.new do
            plugin 'slather'
            plugin 'cocoapods-keys', :keyring => 'Eidolon'
          end.plugins.should == {
            'slather' => {},
            'cocoapods-keys' => {
              'keyring' => 'Eidolon',
            },
          }
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Representation' do
      it 'returns the hash representation' do
        podfile = Podfile.new do
          pod 'ASIHTTPRequest'
          target 'App' do
          end
        end
        podfile.to_hash.should == {
          'target_definitions' => [
            'name' => 'Pods',
            'abstract' => true,
            'dependencies' => ['ASIHTTPRequest'],
            'children' => [
              {
                'name' => 'App',
              },
            ],
          ],
        }
      end

      it 'includes the podfile wide settings in the hash representation' do
        podfile = Podfile.new do
          workspace('MyApp.xcworkspace')
          generate_bridge_support!
          set_arc_compatibility_flag!
          install! 'install-method', :option1 => 'value1', 'option2' => false
        end
        podfile.to_hash.should == {
          'target_definitions' => [{ 'name' => 'Pods', 'abstract' => true }],
          'workspace' => 'MyApp.xcworkspace',
          'generate_bridge_support' => true,
          'set_arc_compatibility_flag' => true,
          'installation_method' => {
            'name' => 'install-method',
            'options' => {
              :option1 => 'value1',
              'option2' => false,
            },
          },
        }
      end

      it 'includes the targets definitions tree in the hash representation' do
        podfile = Podfile.new do
          pod 'ASIHTTPRequest'
          target 'sub-target' do
            pod 'JSONKit'
            target 'test_target' do
              inherit!(:search_paths)
            end
          end
        end
        podfile.to_hash.should == {
          'target_definitions' => [
            {
              'name' => 'Pods',
              'abstract' => true,
              'dependencies' => ['ASIHTTPRequest'],
              'children' => [
                {
                  'name' => 'sub-target',
                  'dependencies' => ['JSONKit'],
                  'children' => [
                    {
                      'name' => 'test_target',
                      'abstract' => false,
                      'inheritance' => 'search_paths',
                    },
                  ],
                },
              ],
            },
          ],
        }
      end

      it 'returns the yaml representation' do
        podfile = Podfile.new do
          pod 'ASIHTTPRequest'
          pod 'JSONKit', '> 1.0', :inhibit_warnings => true
          generate_bridge_support!
          set_arc_compatibility_flag!
          install! 'install-method', :option1 => 'value1', 'option2' => false
        end
        expected = <<-EOF.strip_heredoc
          ---
          installation_method:
            name: install-method
            options:
              :option1: value1
              option2: false
          target_definitions:
          - name: Pods
            abstract: true
            dependencies:
            - ASIHTTPRequest
            - JSONKit:
              - '> 1.0'
            inhibit_warnings:
              for_pods:
                - 'JSONKit'
          generate_bridge_support: true
          set_arc_compatibility_flag: true
        EOF
        YAMLHelper.load_string(podfile.to_yaml).should ==
          YAMLHelper.load_string(expected)
      end

      describe '#checksum' do
        it 'returns the checksum of the file in which it is defined' do
          podfile = Podfile.from_file(fixture('Podfile'))
          podfile.checksum.should == 'c140d332c2d286f26b6439dc3570be477d1897b8'
        end

        it 'returns a nil checksum if the podfile is not defined in a file' do
          podfile = Podfile.new
          podfile.checksum.should.be.nil
        end
      end

      it 'includes inhibit warnings per pod' do
        podfile = Podfile.new do
          pod 'ASIHTTPRequest', :inhibit_warnings => true
          pod 'ObjectiveSugar'
        end
        podfile.to_hash.should == {
          'target_definitions' => [
            'name' => 'Pods',
            'abstract' => true,
            'inhibit_warnings' => {
              'for_pods' => ['ASIHTTPRequest'],
            },
            'dependencies' => %w(ASIHTTPRequest ObjectiveSugar),
          ],
        }
      end

      it 'excludes inhibit warnings per pod' do
        podfile = Podfile.new do
          pod 'ASIHTTPRequest', :inhibit_warnings => false
          pod 'ObjectiveSugar'
        end
        podfile.to_hash.should == {
          'target_definitions' => [
            'name' => 'Pods',
            'abstract' => true,
            'inhibit_warnings' => {
              'not_for_pods' => ['ASIHTTPRequest'],
            },
            'dependencies' => %w(ASIHTTPRequest ObjectiveSugar),
          ],
        }
      end

      it 'includes inhibit all warnings' do
        podfile = Podfile.new do
          pod 'ObjectiveSugar'
          inhibit_all_warnings!
        end
        podfile.to_hash.should == {
          'target_definitions' => [
            'name' => 'Pods',
            'abstract' => true,
            'dependencies' => ['ObjectiveSugar'],
            'inhibit_warnings' => {
              'all' => true,
            },
          ],
        }
      end

      it 'includes uses frameworks' do
        podfile = Podfile.new do
          pod 'ObjectiveSugar'
          use_frameworks!
        end
        podfile.to_hash.should == {
          'target_definitions' => [
            'name' => 'Pods',
            'abstract' => true,
            'dependencies' => ['ObjectiveSugar'],
            'uses_frameworks' => true,
          ],
        }
      end

      it 'includes the specified sources in the hash representation' do
        podfile = Podfile.new do
          source 'new_ASIHTTPRequest_source'
          pod 'ASIHTTPRequest'
        end
        podfile.to_hash.should == {
          'sources' => %w(new_ASIHTTPRequest_source),
          'target_definitions' => [
            {
              'name' => 'Pods',
              'abstract' => true,
              'dependencies' => %w(ASIHTTPRequest),
            },
          ],
        }
      end

      it 'includes the specified plugins in the hash representation' do
        podfile = Podfile.new do
          plugin 'slather'
          plugin 'cocoapods-keys', :keyring => 'Eidolon'
          pod 'ASIHTTPRequest'
        end
        podfile.to_hash.should == {
          'plugins' => {
            'slather' => {},
            'cocoapods-keys' => {
              'keyring' => 'Eidolon',
            },
          },
          'target_definitions' => [
            {
              'name' => 'Pods',
              'abstract' => true,
              'dependencies' => %w(ASIHTTPRequest),
            },
          ],
        }
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Class methods' do
      it 'can be initialized from a ruby DSL file' do
        ruby_podfile = Podfile.from_file(fixture('Podfile'))
        ruby_podfile.target_definitions.keys.should == ['Pods']
        ruby_podfile.dependencies.map(&:name).should == %w(SSZipArchive ASIHTTPRequest Reachability ASIWebPageRequest)
      end

      it 'can handle smartquotes in a ruby DSL file' do
        dsl = <<-DSL
          pod “AFNetworking”, ‘~> 2.0’
        DSL
        podfile = Podfile.from_ruby(fixture('Podfile'), dsl)
        podfile.dependencies.should == [Dependency.new('AFNetworking', '~> 2.0')]
        UI.warnings.should.match /smart quotes/
      end

      it 'handles the `podfile` extension' do
        path = fixture('CocoaPods.podfile')
        Pathname.any_instance.stubs(:exist?).returns(true)
        Podfile.expects(:from_ruby)
        Podfile.from_file(path)
      end

      it 'handles the `rb` extension' do
        path = fixture('Podfile.rb')
        Pathname.any_instance.stubs(:exist?).returns(true)
        Podfile.expects(:from_ruby)
        Podfile.from_file(path)
      end

      it 'can be initialized from a YAML file' do
        ruby_podfile = Podfile.from_file(fixture('Podfile'))
        yaml_podfile = Podfile.from_file(fixture('Podfile.yaml'))
        ruby_podfile.to_hash.should == yaml_podfile.to_hash
      end

      it "raises if the given initialization file doesn't exists" do
        should.raise Informative do
          Podfile.from_file('Missing-file')
        end.message.should.match /No Podfile exists/
      end

      it 'raises if the given initialization file has an unsupported extension' do
        Pathname.any_instance.stubs(:exist?).returns(true)
        File.stubs(:open).returns('')
        should.raise Informative do
          Podfile.from_file('Podfile.json')
        end.message.should.match /Unsupported Podfile format/
      end

      it 'can be initialized from a hash' do
        fixture_podfile = Podfile.from_file(fixture('Podfile'))
        hash = fixture_podfile.to_hash
        podfile = Podfile.from_hash(hash)
        podfile.to_hash.should == fixture_podfile.to_hash
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Private helpers' do
      it 'sets and retrieves a value in the internal hash' do
        podfile = Podfile.new
        podfile.send(:set_hash_value, 'generate_bridge_support', true)
        podfile.send(:get_hash_value, 'generate_bridge_support').should.be.true
      end

      it 'allows specifying a default value when fetching from the hash' do
        podfile = Podfile.new

        podfile.send(:get_hash_value, 'generate_bridge_support', 'default').should == 'default'

        podfile.send(:set_hash_value, 'generate_bridge_support', true)
        podfile.send(:get_hash_value, 'generate_bridge_support', 'default').should.be.true
      end

      it 'raises if there is an attempt to access or set an unknown key in the internal hash' do
        podfile = Podfile.new
        lambda { podfile.send(:set_hash_value, 'unknown', true) }.should.raise Pod::Podfile::StandardError
        lambda { podfile.send(:get_hash_value, 'unknown') }.should.raise Pod::Podfile::StandardError
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Nested target definitions' do
      before do
        @podfile = Podfile.new do
          platform :ios
          project 'iOS Project', 'iOS App Store' => :release, 'Test' => :debug

          target :debug do
            pod 'SSZipArchive'
          end

          target :test do
            inherit! :search_paths
            inhibit_all_warnings!
            use_frameworks!
            pod 'JSONKit'
            target :subtarget do
              pod 'Reachability'
            end
          end

          target :osx_target do
            platform :osx
            project 'OSX Project.xcodeproj', 'Mac App Store' => :release, 'Test' => :debug
            pod 'ASIHTTPRequest'
            target :nested_osx_target do
            end
          end

          pod 'ASIHTTPRequest'
        end
      end

      it 'adds dependencies outside of any explicit target block to the default target' do
        target = @podfile.target_definitions['Pods']
        target.label.should == 'Pods'
        target.dependencies.should == [Dependency.new('ASIHTTPRequest')]
      end

      it 'adds dependencies of the outer target to non-exclusive targets' do
        target = @podfile.target_definitions[:debug]
        target.label.should == 'Pods-debug'
        target.dependencies.sort_by(&:name).should == [
          Dependency.new('ASIHTTPRequest'),
          Dependency.new('SSZipArchive'),
        ]
      end

      it 'does not add dependencies of the outer target to exclusive targets' do
        target = @podfile.target_definitions[:test]
        target.label.should == 'Pods-test'
        target.dependencies.should == [Dependency.new('JSONKit')]
      end

      it 'adds dependencies of the outer target to nested targets' do
        target = @podfile.target_definitions[:subtarget]
        target.label.should == 'Pods-test-subtarget'
        target.dependencies.should == [Dependency.new('Reachability'), Dependency.new('JSONKit')]
      end

      it 'returns the platform of the target' do
        @podfile.target_definitions['Pods'].platform.should == :ios
        @podfile.target_definitions[:test].platform.should == :ios
        @podfile.target_definitions[:osx_target].platform.should == :osx
      end

      it 'assigns a deployment target to the platforms if not specified' do
        @podfile.target_definitions['Pods'].platform.deployment_target.to_s.should == '4.3'
        @podfile.target_definitions[:test].platform.deployment_target.to_s.should == '4.3'
        @podfile.target_definitions[:osx_target].platform.deployment_target.to_s.should == '10.6'
      end

      it "automatically marks a target as exclusive if the parent platform doesn't match" do
        @podfile.target_definitions[:osx_target].should.be.exclusive
        @podfile.target_definitions[:nested_osx_target].should.not.be.exclusive
      end

      it 'inhibits warnings for any asked pod if inhibit_all_warnings! is called' do
        @podfile.target_definitions['Pods'].inhibits_warnings_for_pod?('SSZipArchive').should.not.be.true
        @podfile.target_definitions[:test].inhibits_warnings_for_pod?('JSONKit').should.be.true
        @podfile.target_definitions[:subtarget].inhibits_warnings_for_pod?('Reachability').should.be.true
      end

      it 'uses frameworks for any target if use_frameworks! is called' do
        @podfile.target_definitions['Pods'].uses_frameworks?.should.not.be.true
        @podfile.target_definitions[:test].uses_frameworks?.should.be.true
        @podfile.target_definitions[:subtarget].uses_frameworks?.should.be.true
      end

      it 'returns the Xcode project that contains the target to link with' do
        ['Pods', :debug, :test, :subtarget].each do |target_name|
          target = @podfile.target_definitions[target_name]
          target.user_project_path.to_s.should == 'iOS Project.xcodeproj'
        end
        [:osx_target, :nested_osx_target].each do |target_name|
          target = @podfile.target_definitions[target_name]
          target.user_project_path.to_s.should == 'OSX Project.xcodeproj'
        end
      end
    end

    #-------------------------------------------------------------------------#
  end
end
